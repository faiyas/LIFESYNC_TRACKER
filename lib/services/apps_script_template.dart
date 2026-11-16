/// Standalone Google Apps Script (Code.gs) template that users can copy-paste into Google Sheets
class AppsScriptTemplate {
  static const String code = r'''/**
 * LifeSync Tracker - Universal 2-Way Google Apps Script Engine
 * 
 * 1. POST: Automatically backs up ALL SQLite database tables into formatted Google Sheet tabs.
 * 2. GET: Automatically exports/restores Google Sheet tables back to SQLite database for 2-way sync.
 */

function doGet(e) {
  try {
    var action = (e && e.parameter && e.parameter.action) ? e.parameter.action : 'status';
    
    // 2-Way Restore Engine: Fetch all table tabs and return structured JSON
    if (action === 'restore' || action === 'fetch_all') {
      var spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
      var sheets = spreadsheet.getSheets();
      var resultData = {};
      var tableCount = 0;

      for (var s = 0; s < sheets.length; s++) {
        var sheet = sheets[s];
        var name = sheet.getName();
        if (name === 'Sync_Overview') continue;

        var lowerTableName = name.toLowerCase();
        var data = sheet.getDataRange().getValues();
        if (data.length < 2) continue;

        var headers = data[0];
        var rows = [];
        for (var r = 1; r < data.length; r++) {
          var rowObj = {};
          var isEmpty = true;
          for (var c = 0; c < headers.length; c++) {
            var colKey = headers[c];
            var val = data[r][c];
            if (val !== '' && val !== null && val !== undefined) {
              isEmpty = false;
            }
            if (val === 'Yes') val = 1;
            if (val === 'No') val = 0;
            rowObj[colKey] = val;
          }
          if (!isEmpty) {
            rows.push(rowObj);
          }
        }
        resultData[lowerTableName] = rows;
        tableCount++;
      }

      return ContentService.createTextOutput(JSON.stringify({
        status: 'success',
        action: 'restore',
        totalTables: tableCount,
        data: resultData
      })).setMimeType(ContentService.MimeType.JSON);
    }

    return ContentService.createTextOutput(JSON.stringify({
      status: 'success',
      message: 'LifeSync Universal 2-Way Backup & Restore Engine is online and ready for sync!'
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      status: 'error',
      message: err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return ContentService.createTextOutput(JSON.stringify({
        status: 'error',
        message: 'No POST data received'
      })).setMimeType(ContentService.MimeType.JSON);
    }

    var payload = JSON.parse(e.postData.contents);
    var spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
    var allData = payload.data || {};
    var syncedAt = payload.timestamp || new Date().toISOString();
    var summaryCounts = {};

    function formatSheetTitle(rawName) {
      return rawName.charAt(0).toUpperCase() + rawName.slice(1);
    }

    // Process every single table sent from SQLite database
    for (var tableName in allData) {
      var records = allData[tableName] || [];
      var sheetName = formatSheetTitle(tableName);
      var sheet = spreadsheet.getSheetByName(sheetName);
      if (!sheet) {
        sheet = spreadsheet.insertSheet(sheetName);
      }

      sheet.clearContents();
      sheet.clearFormats();

      if (records.length === 0) {
        sheet.getRange(1, 1).setValue('No records logged yet for ' + tableName).setFontStyle('italic').setFontColor('#64748B');
        summaryCounts[sheetName] = 0;
        continue;
      }

      var headerSet = {};
      for (var i = 0; i < records.length; i++) {
        var rowObj = records[i];
        for (var key in rowObj) {
          headerSet[key] = true;
        }
      }
      var headers = Object.keys(headerSet);

      if (headers.length === 0) {
        summaryCounts[sheetName] = 0;
        continue;
      }

      // Write Header Row
      var headerRange = sheet.getRange(1, 1, 1, headers.length);
      headerRange.setValues([headers]);
      headerRange.setFontWeight('bold');
      headerRange.setBackground('#0284C7');
      headerRange.setFontColor('#FFFFFF');

      // Prepare 2D Matrix of Rows
      var matrix = [];
      for (var r = 0; r < records.length; r++) {
        var rowItem = records[r];
        var rowArr = [];
        for (var c = 0; c < headers.length; c++) {
          var val = rowItem[headers[c]];
          if (val === null || val === undefined) {
            rowArr.push('');
          } else if (typeof val === 'boolean') {
            rowArr.push(val ? 'Yes' : 'No');
          } else {
            rowArr.push(val);
          }
        }
        matrix.push(rowArr);
      }

      if (matrix.length > 0) {
        var dataRange = sheet.getRange(2, 1, matrix.length, headers.length);
        dataRange.setValues(matrix);
      }

      // Auto-fit column widths
      for (var col = 1; col <= headers.length; col++) {
        sheet.autoResizeColumn(col);
      }

      summaryCounts[sheetName] = matrix.length;
    }

    // Create or Update 'Sync_Overview' Dashboard Sheet
    var overviewSheet = spreadsheet.getSheetByName('Sync_Overview');
    if (!overviewSheet) {
      overviewSheet = spreadsheet.insertSheet('Sync_Overview', 0);
    }
    overviewSheet.clearContents();
    overviewSheet.clearFormats();

    overviewSheet.getRange(1, 1, 1, 2).setValues([['LifeSync Backup Overview', 'Status / Count']]).setFontWeight('bold').setBackground('#10B981').setFontColor('#FFFFFF');
    var overviewData = [
      ['Last Synchronized', syncedAt],
      ['App Edition', 'Flutter Offline-First SQLite with Universal 2-Way Cloud Sync'],
      ['Total Tables Synced', Object.keys(allData).length]
    ];
    for (var sn in summaryCounts) {
      overviewData.push([sn + ' Records', summaryCounts[sn]]);
    }
    overviewSheet.getRange(2, 1, overviewData.length, 2).setValues(overviewData);
    overviewSheet.autoResizeColumn(1);
    overviewSheet.autoResizeColumn(2);

    return ContentService.createTextOutput(JSON.stringify({
      status: 'success',
      syncedAt: syncedAt,
      totalTables: Object.keys(allData).length,
      summary: summaryCounts
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      status: 'error',
      message: error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

/**
 * Optional 100% Free Cloud Bank Email Auto-Sync:
 * In Google Apps Script, click the clock icon (Triggers) -> Add Trigger -> Choose `syncBankEmailsToExpenses`,
 * Time-driven -> Every 15 minutes.
 * Automatically scans your Gmail for bank alerts (HDFC, SBI, ICICI, Axis, Kotak, CRED)
 * and appends new transactions to your expenses sheet with zero API fees!
 */
function syncBankEmailsToExpenses() {
  try {
    var spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
    var expensesSheet = spreadsheet.getSheetByName('expenses');
    if (!expensesSheet) return;

    var query = 'from:(alerts@hdfcbank.net OR alerts@sbi.co.in OR ibankingalerts@icicibank.com OR AxisBank OR Kotak OR cred.club) (debited OR spent OR "transaction alert") newer_than:2d';
    var threads = GmailApp.search(query, 0, 15);

    for (var i = 0; i < threads.length; i++) {
      var messages = threads[i].getMessages();
      for (var j = 0; j < messages.length; j++) {
        var body = messages[j].getPlainBody();
        var matchAmount = body.match(/(?:INR|Rs\.?|₹)\s*([\d,]+\.?\d*)/i);
        if (matchAmount) {
          var amount = parseFloat(matchAmount[1].replace(/,/g, ''));
          if (amount > 0) {
            var date = Utilities.formatDate(messages[j].getDate(), Session.getScriptTimeZone(), 'yyyy-MM-dd');
            var time = Utilities.formatDate(messages[j].getDate(), Session.getScriptTimeZone(), 'HH:mm');
            var subject = messages[j].getSubject();

            expensesSheet.appendRow([
              'email_' + messages[j].getId(),
              'default_profile',
              amount,
              'General',
              'Bank Email',
              date,
              time,
              '[Bank Email Auto-Captured] ' + subject,
              '', '', '', 'INR', 0,
              new Date().toISOString()
            ]);
          }
        }
      }
    }
  } catch (err) {
    Logger.log('Bank Email Sync Error: ' + err.toString());
  }
}
''';
}
