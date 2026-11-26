-- ATP :: PDT_OIC_DEV5 into PDT_OIC_DEV2
-- PDT_OIC_DEV5 into PDT_OIC_DEV2, generated 2026-11-26 09:32 UTC
--
-- Run against the TARGET database:  sql <user>@<target> @install.sql
-- Drops run first, then creates and alters, then recompiles.

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
SET DEFINE OFF;
SET ECHO OFF;

PROMPT ============================================================
PROMPT Create, replace and alter
PROMPT ============================================================

PROMPT [1] CREATE TABLE PDT_OIC.TEST_MIGRATION
@@atp/PDT_OIC/001_table_test_migration.sql

PROMPT ============================================================
PROMPT Done. Check for invalid objects before signing off:
PROMPT   SELECT object_name, object_type FROM user_objects WHERE status <> 'VALID';
PROMPT ============================================================
