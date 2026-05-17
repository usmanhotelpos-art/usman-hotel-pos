import fs from 'fs';
import path from 'path';
import { readDb } from './db.js';

const BACKUP_DIR = 'E:/BACKUP OF POS USMAN HOTEL';

// Create backup directory if it doesn't exist
if (!fs.existsSync(BACKUP_DIR)) {
  fs.mkdirSync(BACKUP_DIR, { recursive: true });
}

export function createBackup() {
  try {
    const db = readDb();
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
    const filename = `pos_backup_${timestamp}.json`;
    const filepath = path.join(BACKUP_DIR, filename);

    const backupData = {
      timestamp: new Date().toISOString(),
      hotelName: db.settings?.hotelName || 'Usman Hotel',
      data: db
    };

    fs.writeFileSync(filepath, JSON.stringify(backupData, null, 2), 'utf8');
    
    return {
      success: true,
      filename,
      filepath,
      message: `Backup created: ${filename}`
    };
  } catch (error) {
    return {
      success: false,
      error: error.message
    };
  }
}

export function listBackups() {
  try {
    if (!fs.existsSync(BACKUP_DIR)) {
      return { success: true, backups: [] };
    }

    const files = fs.readdirSync(BACKUP_DIR)
      .filter(file => file.endsWith('.json') && file.startsWith('pos_backup_'))
      .map(file => ({
        filename: file,
        path: path.join(BACKUP_DIR, file),
        size: fs.statSync(path.join(BACKUP_DIR, file)).size,
        created: fs.statSync(path.join(BACKUP_DIR, file)).mtime
      }))
      .sort((a, b) => b.created - a.created);

    return {
      success: true,
      backups: files
    };
  } catch (error) {
    return {
      success: false,
      error: error.message
    };
  }
}

export function restoreBackup(filepath) {
  try {
    if (!fs.existsSync(filepath)) {
      return {
        success: false,
        error: 'Backup file not found'
      };
    }

    const fileContent = fs.readFileSync(filepath, 'utf8');
    const backupData = JSON.parse(fileContent);
    
    // Create safety backup before restore
    const safetyBackupPath = path.join(
      BACKUP_DIR,
      `safety_backup_before_restore_${new Date().getTime()}.json`
    );
    const currentDb = readDb();
    fs.writeFileSync(safetyBackupPath, JSON.stringify(currentDb, null, 2), 'utf8');

    // Write the restored data back to the main db file
    const dbFile = path.join(process.cwd(), 'server', 'data', 'db.json');
    fs.writeFileSync(dbFile, JSON.stringify(backupData.data, null, 2), 'utf8');

    return {
      success: true,
      message: 'Backup restored successfully',
      safetyBackup: safetyBackupPath
    };
  } catch (error) {
    return {
      success: false,
      error: error.message
    };
  }
}

export function deleteBackup(filepath) {
  try {
    if (!fs.existsSync(filepath)) {
      return {
        success: false,
        error: 'Backup file not found'
      };
    }

    fs.unlinkSync(filepath);
    return {
      success: true,
      message: 'Backup deleted successfully'
    };
  } catch (error) {
    return {
      success: false,
      error: error.message
    };
  }
}
