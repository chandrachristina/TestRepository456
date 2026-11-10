-- ATP :: PDT_OIC_DEV2 into PDT_OIC_DEV5
-- PDT_OIC_DEV2 into PDT_OIC_DEV5, generated 2026-11-10 14:58 UTC
--
-- Run against the TARGET database:  sql <user>@<target> @install.sql
-- Drops run first, then creates and alters, then recompiles.

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
SET DEFINE OFF;
SET ECHO OFF;

PROMPT ============================================================
PROMPT Create, replace and alter
PROMPT ============================================================

PROMPT [1] REPLACE PACKAGE PDT_OIC.PANDUIT_SO_ORACLE_ERP_TO_WMS_PKG
@@atp/PDT_OIC/001_package_panduit_so_oracle_erp_to_wms_pkg.sql

PROMPT ============================================================
PROMPT Recompile dependents
PROMPT ============================================================

PROMPT [2] COMPILE PACKAGE BODY PDT_OIC.PANDUIT_SO_ORACLE_ERP_TO_WMS_PKG
@@atp/PDT_OIC/002_package_body_panduit_so_oracle_erp_to_wms_pkg__compile.sql

PROMPT ============================================================
PROMPT Done. Check for invalid objects before signing off:
PROMPT   SELECT object_name, object_type FROM user_objects WHERE status <> 'VALID';
PROMPT ============================================================
