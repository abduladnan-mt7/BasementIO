# Runbook: restore a database from backup

**Rule: always restore into a scratch database first, check the data, and only then touch production.** A restore replaces the existing data, and a bad restore over production is worse than the original problem.

Scheduled backups are **dumps**, so you can restore to a backup time (at most an hour back for hourly backups). To restore to an exact moment, use point-in-time restore (Phase 3, Postgres only).

## 1. Pick the backup
Dashboard → database → **Backups**: find the run just **before** the problem started. The same files are also in the R2 bucket.

## 2. Restore into a scratch database
1. In the project's **staging** environment, create a new database of the same engine and version named `<project>-restore`.
2. Load the backup into it. Either:
   - **From the dashboard:** open the scratch database → **Import Backup**, and upload or choose the file. It uses `pg_restore` for Postgres.
   - **Manually** (download the file from R2 first; check its extension):
     ```bash
     # Postgres, custom-format dump
     pg_restore --no-owner --no-acl -d "$SCRATCH_URL" backup.dmp
     # Postgres, pg_dumpall .gz
     gunzip -c backup.gz | psql "$SCRATCH_URL"
     # MySQL / MariaDB
     gunzip -c backup.gz | mysql -h HOST -u USER -p DBNAME    # or: mysql ... < backup.sql
     # MongoDB
     mongorestore --uri "$SCRATCH_URL" --gzip --archive=backup.gz
     ```

## 3. Check the data
In CloudBeaver (or `psql`), check the row counts on key tables, the most recent records, and the specific data you're trying to recover.

## 4. Choose how to bring it back
- **Only some rows or tables were lost:** copy just those from scratch to production (export/import the affected tables). Production keeps everything written since the backup.
- **The whole database is bad:** stop the app (or turn on maintenance mode) so nothing writes, run **Import Backup** on the production database, start the app, and smoke test.

## 5. Clean up
Delete the `<project>-restore` database, then write down what happened and when, and how long the restore took.

## Monthly drill
Restore the latest production backup of one project into scratch and compare row counts. A backup you've never restored is only a hope that it works.
