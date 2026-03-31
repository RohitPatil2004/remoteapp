const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

// Ensure data folder exists
const dataDir = path.join(__dirname, '../data');
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

const DB_PATH = path.join(dataDir, 'remoteapp.db');
let db;

// Initialize and return the database
function getDB() {
  if (!db) {
    db = new Database(DB_PATH);
    db.pragma('journal_mode = WAL'); // Better performance
    db.pragma('foreign_keys = ON');  // Enforce FK constraints
  }
  return db;
}

// Create all tables
function initDB() {
  return new Promise((resolve, reject) => {
    try {
      const database = getDB();

      // Users table
      database.exec(`
        CREATE TABLE IF NOT EXISTS users (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          full_name   TEXT    NOT NULL,
          email       TEXT    NOT NULL UNIQUE,
          password    TEXT    NOT NULL,
          device_code TEXT    NOT NULL UNIQUE,
          is_active   INTEGER NOT NULL DEFAULT 1,
          created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
          last_login  TEXT
        );
      `);

      // Sessions table — tracks active JWT sessions
      database.exec(`
        CREATE TABLE IF NOT EXISTS sessions (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id     INTEGER NOT NULL,
          token_hash  TEXT    NOT NULL UNIQUE,
          device_info TEXT,
          ip_address  TEXT,
          created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
          expires_at  TEXT    NOT NULL,
          is_active   INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );
      `);

      // Connection logs — tracks who connected to whom
      database.exec(`
        CREATE TABLE IF NOT EXISTS connection_logs (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          initiator_id    INTEGER NOT NULL,
          target_code     TEXT    NOT NULL,
          status          TEXT    NOT NULL DEFAULT 'pending',
          connected_at    TEXT,
          disconnected_at TEXT,
          created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (initiator_id) REFERENCES users(id) ON DELETE CASCADE
        );
      `);

      console.log('[DB] Tables created/verified successfully');
      resolve(true);
    } catch (err) {
      reject(err);
    }
  });
}

module.exports = { getDB, initDB };
