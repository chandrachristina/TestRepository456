-- CI/CD Migrator
-- RICE       : TEST02
-- Object     : PACKAGE BODY PDT_OIC.PANDUIT_SO_ORACLE_ERP_TO_WMS_PKG
-- Action     : REPLACE
-- Promoting  : PDT_OIC_DEV2 into PDT_OIC_DEV5
-- Why        : Replaced from the source definition.
-- ----------------------------------------------------------

CREATE OR REPLACE EDITIONABLE PACKAGE BODY "PDT_OIC"."PANDUIT_SO_ORACLE_ERP_TO_WMS_PKG" AS
/**************************************************************************************************************************************
    ** $Header$                                                                                                                          **
    ** Program Name    : panduit_so_oracle_erp_to_wms_pkg.pkb                                                                           **
    ** Language        : PL/SQL                                                                                                          **
    ** Description     : This Package is created for interfacing Sales Order data from oracle to WMS                                           **
    **                                                                                                                                   **
    ** HISTORY                                                                                                                           **
    ** ==================================================================================================================================**
    ** Author                      Version                                                                                                **
    ** ==================================================================================================================================**
    ** Tanat Vatsal              1.0 - Initial Version       
    ** Abdul Shaikh              1.1 - Changes done as part of CON0001205-81784
    ** Srinivasarao Kancharla    1.2 - Changes done as part of CON0001205-89271
	** Shreen Naaz				 1.3 - Changes done as part of CON0001205-89997
    ** Chandra Christina	     1.4 - Changes done as part of CON0001205-110227
	** Chandra Christina	     1.5 - Changes done as part of CON0001205-109792
    ** Chandra Christina	     1.6 - Changes done as part of CON0001205-110172(Performance issue - Added WITH clauses and query tuning  )
	** Chandra Christina	     1.7 - Changes done as part of CON0001205-116229(Junk Chracter)
	** Urvashi Chauhan	         1.8 - Changes done as part of CON0001205-117414(UTF-8 conversion issue for blank spaces at header EFF)
    ** Chandra Christina	     1.9 - Changes done as part of CON0001205-104993(coc attribute)
	** Chandra Christina	     2.0 - Changes done as part of CON0001205-119779(Batch logic)
    ** Abdul Shaik      	     2.1 - Changes done as part of CON0001205-125552,(Batch logic)
    ** Abdul Shaik      	     2.1 - Changes done as part of CON0001205-133192,(SHIP_TO and BILL_TO logic)
***************************************************************************************************************************************/

/**********************************************************************************************************
    ** Program Unit : PROCEDURE
    ** Name         : panduit_insert_sales_order_to_trx_audit_prc
    ** Description  : Procedure to insert Sales Order data into panduit_om_so_to_wms_tbl
***********************************************************************************************************/
    PROCEDURE panduit_insert_sales_order_to_trx_audit_prc (
        p_integration_name           IN VARCHAR2,
        p_integration_identifier     IN VARCHAR2,
        p_integration_version        IN VARCHAR2,
        --p_instance_id                IN NUMBER,
        p_instance_id                IN VARCHAR2,
        p_from_ship_date             IN DATE,
        p_to_ship_date               IN NUMBER,
        p_invoked_by                 IN VARCHAR2,
        p_interface_rice_id          IN VARCHAR2,
        p_source                     IN VARCHAR2,
        p_target                     IN VARCHAR2,
        p_module                     IN VARCHAR2,
        p_last_run_datetime          IN VARCHAR2,
        p_integration_start_datetime IN VARCHAR2,
        p_business_relationship      IN VARCHAR2,
        p_insert_batch_limit         IN NUMBER,
        p_rec_inserted               OUT NUMBER,
        p_status                     OUT VARCHAR2,
        p_error_message              OUT VARCHAR2
    ) IS
        l_ssd_lookup_type VARCHAR2(50 BYTE) := 'PANDUIT_OM_EBS_WMS_SSD_DAYS';
    BEGIN
        INSERT INTO panduit_om_so_to_wms_tbl (
            oic_instance_id,
            status,
            wmssonum,
            wmssoseqnum,
            last_update_date,
            creation_date,
            created_by,
            last_updated_by,
            order_number,
            order_line_number,
            request_payload,
            business_unit_name,
            rice_id,
            attribute1,
            attribute4,
            attribute5,
            delivery_detail_id,
            attribute2, --added on 9/4/25
            attribute3, --added on 21/4/25,
            otm_status
        )
            ( SELECT
                oic_instance_id,
                status,
                wmssonum,
                wmssoseqnum,
                last_update_date,
                creation_date,
                created_by,
                last_updated_by,
                order_number,
                order_line_number,
                request_payload,
                business_unit_name,
                rice_id,
                attribute1,
                attribute4,
                attribute5,
                delivery_detail_id,
                attribute2,
                attribute3,
                otm_status
            FROM
                (
                    WITH get_wmssoseqnum AS (
                        SELECT
                            MAX(a.wmssoseqnum) max_wmssoseqnum,
                            a.order_number
                        FROM
                            panduit_om_so_to_wms_tbl a
                        WHERE
                            a.status = 'SUCCESS'
                        GROUP BY
                            a.order_number
                    )
                    SELECT
                        p_instance_id                                                          oic_instance_id,
                        'NEW'                                                                  status,
                        NULL                                                                   wmssonum,
                        nvl((
                            SELECT
                                max_wmssoseqnum
                            FROM
                                get_wmssoseqnum a
                            WHERE
                                a.order_number = dha.order_number
                        ), 0)                                                                  wmssoseqnum,
                        sysdate                                                                last_update_date,
                        sysdate                                                                creation_date,
                        NULL                                                                   created_by,
                        NULL                                                                   last_updated_by,
                        dha.order_number                                                       order_number,
                        dla.display_line_number                                                order_line_number,
                        NULL                                                                   request_payload,
                        pbut.business_unit_name,
                        p_interface_rice_id                                                    rice_id,
                        dfla.fulfill_line_id                                                   attribute1,
                        concat(concat(dla.display_line_number, '-'), dfla.fulfill_line_number) attribute4,
                        iop.organization_code                                                  attribute5,
                        wshd.delivery_detail_id                                                delivery_detail_id,
                        wdd.requested_quantity                                                 attribute2,
                        (
                            SELECT
                                SUM(to_number(nvl(wdd1.requested_quantity, 0)))
                            FROM
                                panduit_wsh_delivery_details_tbl     wdd1,
                                panduit_wsh_delivery_details_dff_tbl wshd1
                            WHERE
                                    1 = 1
                                AND wdd1.source_header_number = wshd1.source_header_number
                                AND wdd1.inventory_item_id = wshd1.inventory_item_id
                                AND wdd1.source_line_number = wshd1.source_line_number
                                AND wdd1.delivery_detail_id = wshd1.delivery_detail_id
                                AND wshd1.source_header_number = dha.order_number
                                    --AND wshd1.source_line_number = dla.display_line_number --Commented on 18/06/25
                                AND wdd1.source_line_number = dla.line_number
                                AND nvl(dfla.fulfillment_split_ref_id, dfla.fulfill_line_id) = wdd1.source_shipment_id
                                AND wshd1.wms_interfaced_flag = 'INTERFACED'
                        )                                                                      attribute3,
                        nvl((
                            SELECT
                                'NEW'
                            FROM
                                panduit_fnd_lookup_values_tbl flv
                            WHERE
                                    flv.lookup_type = 'PANDUIT_ORGS_OTM'
                                AND flv.meaning = iop.organization_code
                                AND flv.language = 'US'
                                 AND flv.enabled_flag = 'Y'
                        ), 'NA')                                                               otm_status
                    FROM
                        (
                            SELECT
                                a.*,
                                MAX(object_version_number)
                                OVER(PARTITION BY order_number) max_ovn
                            FROM
                                pdt_erp_datasync.panduit_doo_headers_all_tbl a
                        )                                                     dha,
                        panduit_doo_lines_all_tbl                             dla,
                        panduit_business_unit_tbl                             pbut,
                        panduit_doo_fulfill_lines_all_tbl                     dfla,
                        pdt_erp_datasync.panduit_inv_org_parameters_tbl       iop,
                        pdt_erp_datasync.panduit_wsh_delivery_details_tbl     wdd,
                        pdt_erp_datasync.panduit_doo_fulfill_lines_eff_b_tbl  dfleb,
                        pdt_erp_datasync.panduit_wsh_delivery_details_dff_tbl wshd,
                        pdt_erp_datasync.panduit_fnd_lookup_values_tbl        pflv1,
                        pdt_erp_datasync.panduit_fnd_lookup_values_tbl        pflv2
                    WHERE
                            1 = 1
                        AND dha.header_id = dla.header_id                        
                        AND pbut.business_unit_id = dha.org_id
                        AND dha.header_id = dfla.header_id
                        AND dfla.line_id = dla.line_id
                        AND dfla.fulfill_org_id = iop.organization_id
                        AND dfla.status_code = pflv1.lookup_code
                        AND pflv1.lookup_type = 'PND_OM_LINE_STATUS'
                        AND pflv1.language = 'US'
                        AND pflv1.enabled_flag = 'Y'
                        /*IN (SELECT
                                lookup_code
                            FROM
                                panduit_fnd_lookup_values_tbl
                            WHERE
                                    lookup_type = 'PND_OM_LINE_STATUS'
                                AND language = 'US')*/
                        AND iop.organization_code = pflv2.meaning
                        AND pflv2.lookup_type = 'PND_WMS_ORGLOC_OSP'
                        AND pflv2.language = 'US'
                        AND pflv2.enabled_flag  = 'Y'
                        ---
                        AND wdd.sales_order_number = dha.order_number
                        AND wdd.source_line_number = dla.line_number
                        AND wdd.source_header_number = wshd.source_header_number
                        AND wdd.inventory_item_id = wshd.inventory_item_id
                        AND wdd.source_line_number = wshd.source_line_number
                        AND wdd.delivery_detail_id = wshd.delivery_detail_id
                        AND wshd.attribute13 IS NULL							-- TRUE
                        AND upper(wshd.wms_interfaced_flag) = 'INTERFACED'  	-- TRUE
                        AND nvl(dfla.fulfillment_split_ref_id, dfla.fulfill_line_id) = wdd.source_shipment_id
                        /**********************************************************************************************************
                                         ** Added as part of CON0001205-67064
                        ***********************************************************************************************************/
                        AND dfla.fulfill_line_id = dfleb.fulfill_line_id (+)
                        AND dfleb.context_code (+) = 'InterfacedFlag'
                        --AND dfleb.ATTRIBUTE_CHAR1 = 'Y'
                        /*AND 1 = (
                            CASE
                                WHEN dfleb.attribute_char1 = 'Y' THEN
                                    0
                                ELSE
                                    1
                            END
                        )*/ --Commented on 22/4/25
                        /**********************************************************************************************************
                                     ** Added as part of CON0001205-67064
                        ***********************************************************************************************************/  
                        ---
                        AND dha.submitted_flag = 'Y' --Uncommented as part of CON0001205-89271
                        --AND dha.order_number NOT LIKE '6%' -- Added to Exclude Prod Orders
                        AND dha.order_type_code NOT IN (
                            SELECT
                                tag
                            FROM
                                panduit_fnd_lookup_values_tbl
                            WHERE
                                    lookup_type = 'PANDUIT_OM_INT_EXC_ORDERTYPE'
                                AND language = 'US'
                                AND description = '078'
                        )
                        AND dha.object_version_number = (
                            SELECT
                                MAX(object_version_number)
                            FROM
                                panduit_doo_headers_all_tbl
                            WHERE
                                    order_number = dha.order_number
                                AND status_code IN ( 'OPEN', 'PARTIAL_CLOSE' )
                        )
                        ---
                        AND (
                            SELECT
                                COUNT(*)
                            FROM
                                pdt_erp_datasync.panduit_doo_headers_all_tbl
                            WHERE
                                    header_id = dha.header_id
                                    --order_number = dha.order_number
                                AND status_code = 'DOO_CREDIT_REVIEW_PENDING'
                                AND object_version_number = dha.max_ovn
                        ) = 0
                        AND (
                            SELECT
                                COUNT(*)
                            FROM
                                pdt_oic.panduit_om_so_to_wms_tbl
                            WHERE
                                    order_number = wdd.sales_order_number
                                                            -- AND order_line_number = wdd.source_line_number --Commented on 18/06/25
                                AND order_line_number = dla.display_line_number
                                AND attribute1 = dfla.fulfill_line_id
                                AND ( ( status = 'SUCCESS'
                                        AND dfla.status_code NOT IN (
                                    SELECT
                                        meaning
                                    FROM
                                        pdt_erp_datasync.panduit_fnd_lookup_values_tbl
                                    WHERE
                                            lookup_type = 'PND_REPROCESS_OM_LINE_STATUS'
                                        AND language = 'US'
                                ) )
                                      OR status = 'NEW' )
                                AND delivery_detail_id = wdd.delivery_detail_id
                        ) = 0
                        /*AND (
                            SELECT
                                COUNT(*)
                            FROM
                                pdt_oic.panduit_om_so_to_wms_tbl
                            WHERE
                                    order_number = wdd.sales_order_number
                                AND order_line_number = dla.display_line_number
                                AND attribute1 = dfla.fulfill_line_id
                                AND status IN ( 'NEW')
                                AND delivery_detail_id = wdd.delivery_detail_id
                                AND attribute5 = iop.organization_code
                        ) = 0*/
                        AND (
                            SELECT
                                COUNT(*)
                            FROM
                                pdt_erp_datasync.panduit_doo_hold_instances_tbl      a,
                                pdt_erp_datasync.panduit_doo_hold_task_instances_tbl b
                            WHERE
                                a.transaction_entity_name1 IN ( 'DOO_ORDER_HEADERS_V', 'DOO_ORDER_FLINES_V', 'DOO_ORDER_LINES_V' )
                                AND a.active_flag = 'Y'
                                AND ( a.transaction_entity_id1 = dfla.header_id
                                      OR a.transaction_entity_id1 = dfla.fulfill_line_id
                                      OR a.transaction_entity_id1 = dla.line_id )
                                AND a.hold_instance_id = b.hold_instance_id
                                AND dfla.on_hold = 'Y'
                        ) = 0
                        --AND to_char(dfla.schedule_ship_date, 'yyyy-mm-dd') BETWEEN to_char(p_from_ship_date, 'yyyy-mm-dd') AND to_char(
                        --p_to_ship_date, 'yyyy-mm-dd')

                        /**********************************************************************************************************
                                    ** Added as part of schedule ship date value derived from lookup
                        ***********************************************************************************************************/                    

                        /**********************************************************************************************************
                            ** Added as part of CON0001205-70009
                        ***********************************************************************************************************/

                        AND to_char(CAST((from_tz(CAST(dfla.schedule_ship_date AS TIMESTAMP), '+00:00') AT TIME ZONE(iop.timezone_code))
                        AS TIMESTAMP), 'YYYY-MM-DD') <= (
                            SELECT
                                to_char(panduit_msc_calendar_dates_tbl.calendar_date, 'YYYY-MM-DD')
                            FROM
                                panduit_msc_calendar_dates_tbl,
                                panduit_msc_calendars_tbl
                            WHERE
                                    panduit_msc_calendar_dates_tbl.seq_num = (
                                        SELECT
                                            msc_calendar_dates.prior_seq_num + (
                                                SELECT
                                                    coalesce((
                                                        SELECT
                                                            flv1.attribute1
                                                        FROM
                                                            panduit_fnd_lookup_values_tbl flv1
                                                        WHERE
                                                                flv1.lookup_type = l_ssd_lookup_type
                                                            AND flv1.tag = dha.order_type_code
                                                            AND flv1.description = pbut.business_unit_name
                                                            AND flv1.language = 'US'
                                                            AND flv1.enabled_flag  = 'Y'
                                                    ),(
                                                        SELECT
                                                            flv12.attribute1
                                                        FROM
                                                            panduit_fnd_lookup_values_tbl flv12
                                                        WHERE
                                                                flv12.lookup_type = l_ssd_lookup_type
                                                            AND flv12.tag = dha.order_type_code
                                                            AND flv12.description = 'Default'
                                                            AND flv12.language = 'US'
                                                            AND flv12.enabled_flag = 'Y'

                                                    ),(
                                                        SELECT
                                                            flv3.attribute1
                                                        FROM
                                                            panduit_fnd_lookup_values_tbl flv3
                                                        WHERE
                                                                flv3.lookup_type = l_ssd_lookup_type
                                                            AND flv3.language = 'US'
                                                            AND flv3.tag = 'Default'
                                                            AND flv3.description = 'Default'
                                                            AND flv3.enabled_flag  = 'Y'
                                                    ))
                                                FROM
                                                    dual
                                            )
                                        FROM
                                            panduit_msc_calendar_dates_tbl msc_calendar_dates,
                                            panduit_msc_calendars_tbl      msc_calendars
                                        WHERE
                                                msc_calendars.calendar_code = msc_calendar_dates.calendar_code
                                            AND to_char(iop.schedule_id) = msc_calendars.sr_calendar_code
                                            AND to_char(msc_calendar_dates.calendar_date, 'YYYY-MM-DD') = to_char(CAST((from_tz(CAST(
                                            systimestamp AS TIMESTAMP), '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP), 'YYYY-MM-DD')
                                    )
                                AND panduit_msc_calendar_dates_tbl.calendar_code = panduit_msc_calendars_tbl.calendar_code
                                AND to_char(iop.schedule_id) = panduit_msc_calendars_tbl.sr_calendar_code
                        )
                        /**********************************************************************************************************
                            ** Added as part of CON0001205-70009
                        ***********************************************************************************************************/ 
                        --AND dha.order_number IN ('50000119' )
                    --FETCH FIRST 5 ROWS ONLY
                    FETCH FIRST p_insert_batch_limit ROWS ONLY
                )
            );

        p_rec_inserted := SQL%rowcount;
        COMMIT;
        p_status := 'SUCCESS';
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_error_message := 'Error in fetching Data from Base tables '
                               || sqlerrm
                               || ' '
                               || dbms_utility.format_error_backtrace;
            ROLLBACK;
            BEGIN
                UPDATE panduit_om_so_to_wms_tbl
                SET
                    status = 'ERROR',
                    error_message = p_error_message
                WHERE
                    oic_instance_id = p_instance_id;

                COMMIT;
            END;

    END panduit_insert_sales_order_to_trx_audit_prc;

/**********************************************************************************************************
    ** Program Unit : PROCEDURE
    ** Name         : panduit_get_order_for_wms_prc
    ** Description  : Procedure to fetch Sales Order data from panduit_om_so_to_wms_tbl for processing
***********************************************************************************************************/

    PROCEDURE panduit_get_order_for_wms_prc (
        p_instance_id            IN VARCHAR2,
        p_integration_identifier IN VARCHAR2,
		p_batch_number           IN VARCHAR2,
        p_status                 OUT VARCHAR2,
        p_error_message          OUT VARCHAR2,
        p_order_data             OUT panduit_scm_fetch_source_order_for_wms_tab_typ
    ) AS
        var_order_data panduit_scm_fetch_source_order_for_wms_tab_typ;
    BEGIN
        BEGIN
            SELECT
                panduit_scm_fetch_source_order_for_wms_rec_typ(order_number
                                                               || '-'
                                                               ||(wmssoseqnum + RANK()
                                                                                OVER(PARTITION BY order_number
                                                                                     ORDER BY
                                                                                         ROWNUM
                                                                                )),
                                                               business_unit_name,
                                                               source_order_system,
                                                               '{"WMSOrderNumber": "'
                                                               || order_number
                                                               || '-'
                                                               ||(wmssoseqnum + RANK()
                                                                                OVER(PARTITION BY order_number
                                                                                     ORDER BY
                                                                                         ROWNUM
                                                                                ))
                                                               || '",'
                                                               || substr(json1_object, 2))
            BULK COLLECT
            INTO var_order_data
            FROM
                (
                    SELECT
                        dha.order_number,
                        pbut.business_unit_name,
                        dha.source_order_system,
                        bt.wmssoseqnum,
                        --,dfla.fulfill_line_id,
                        JSON_OBJECT(
                                KEY 'hdrid' VALUE dha.header_id,
                                        KEY 'warehouse' VALUE iop.organization_code,
                                        KEY 'buname' VALUE pbut.business_unit_name,
                                        KEY 'ordnum' VALUE dha.order_number,
                                        KEY 'ordernum' VALUE dha.order_number,
                                        KEY 'ordtypcde' VALUE dha.order_type_code,
                                        KEY 'custponum' VALUE dha.customer_po_number,
                                        KEY 'orddate' VALUE to_char(CAST((from_tz(CAST(dha.ordered_date AS TIMESTAMP),
                                                                                  '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP
                                                                                  ),
                                                                    'YYYY/MM/DD HH24:MI:SS'),
										/**********************************************************************************************************
                                                              ** Added as part of .CON0001205-59277
										***********************************************************************************************************/
										/* 
										KEY 'btaddress1' VALUE TRIM(substr(nvl(hl.address1, h3.address1), 1, 70)),
										KEY 'btaddress2' VALUE TRIM(substr(nvl(hl.address2, h3.address2),1, 100)),*/ --Commented for change for CR CON0001205-92617
										/**********************************************************************************************************
                                                              ** Added as part of .CON0001205-59277
										***********************************************************************************************************/
										/* 
										KEY 'btaddress3' VALUE nvl(hl.address3, h3.address3),
										KEY 'btaddress4' VALUE nvl(hl.address4, h3.address4),
                                        KEY 'btpstlcde' VALUE nvl(hl.postal_code, h3.postal_code),
                                        KEY 'btcity' VALUE nvl(hl.city, h3.city),
                                        KEY 'btstate' VALUE(
											CASE
												WHEN hl.country = 'CA'
													 OR h3.country = 'CA' THEN
													nvl(hl.province, h3.province)
												ELSE
													nvl(hl.state, h3.state)
											END
										),
                                        KEY 'btcountry' VALUE nvl(hl.country, h3.country),
                                        KEY 'stcustomer' VALUE TRIM(substr(hp2.party_name, 1, 50)),*/ --Commented for change for CR CON0001205-92617

										/**********************************************************************************************************
                                                          ** Added as part of .CON0001205-59277
										***********************************************************************************************************/
										/**********************************************************************************************************
                                                          ** Added as part of .CON0001205-92617
										***********************************************************************************************************/
                                        KEY 'btaddress1' VALUE TRIM(substr(h5.address1, 1, 70)),
                                        KEY 'btaddress2' VALUE TRIM(substr(h5.address2, 1, 100)),
                                        KEY 'btaddress3' VALUE h5.address3,
                                        KEY 'btaddress4' VALUE h5.address4,
                                        KEY 'btpstlcde' VALUE h5.postal_code,
                                        KEY 'btcity' VALUE h5.city,
                                        KEY 'btstate' VALUE(
											CASE
												WHEN h5.country = 'CA' THEN
													h5.province
												ELSE
													h5.state
											END
										),
                                        KEY 'btcountry' VALUE h5.country,
                                        KEY 'stcustomer' VALUE TRIM(substr(hps6.party_site_name, 1, 50)),
										/**********************************************************************************************************
                                                                ** Added as part of .CON0001205-92617
										***********************************************************************************************************/

                                        KEY 'staddress1' VALUE TRIM(substr(nvl(h2.address1, h4.address1),1,70)),
                                        KEY 'staddress2' VALUE TRIM(substr(nvl(h2.address2, h4.address2),1,100)),
										/**********************************************************************************************************
                                                            ** Added as part of .CON0001205-59277
										***********************************************************************************************************/
                                        KEY 'staddress3' VALUE nvl(h2.address3, h4.address3),
                                        KEY 'staddress4' VALUE nvl(h2.address4, h4.address4),
                                        KEY 'stpstlcde' VALUE nvl(h2.postal_code, h4.postal_code),
                                        KEY 'stcity' VALUE nvl(h2.city, h4.city),
                                        KEY 'ststate' VALUE(
											CASE
												WHEN h2.country = 'CA'
													 OR h4.country = 'CA' THEN
													nvl(h2.province, h4.province)
												ELSE
													nvl(h2.state, h4.state)
											END
										),
                                        KEY 'stcountry' VALUE nvl(h2.country, h4.country),
                                        KEY 'emladdrss' VALUE hcp.email_address,
                                        KEY 'phnnbr' VALUE hcp1.phone_number,
                                        KEY 'trncurrcde' VALUE dha.transactional_currency_code,
                                        KEY 'mdeoftranprt' VALUE wdd.mode_of_transport,
                                        KEY 'shpmtdcde' VALUE hp1.party_name,
                                        --KEY 'frttrmcde' VALUE dha.freight_terms_code,
                                        KEY 'earaccshpdte' VALUE dha.earliest_acceptable_ship_date,
                                        KEY 'lstaccshpdte' VALUE dha.latest_acceptable_ship_date,
                                        KEY 'pckinstns' VALUE dha.packing_instructions,
                                        KEY 'shpprtycde' VALUE dha.shipment_priority_code,
                                        KEY 'srvclvl' VALUE wdd.service_level,
										--KEY 'custname' VALUE TRIM(substr(nvl(hp.party_name, hp3.party_name), 1,30)), --Commented for change for CR CON0001205-92617
                                        --KEY 'custname' VALUE TRIM(substr(hzcsua6.party_site_name, 1, 30)),
                                        KEY 'custname' VALUE TRIM(substr(hzcsua6.party_site_name, 1, 50)),
                                        --KEY 'custnumbr' VALUE hca.cust_account_number,
                                        KEY 'custnumbr' VALUE hp.party_number,
                                        KEY 'ordertypecode' VALUE dha.order_type_code,
                                        KEY 'saleschanlcode' VALUE dha.sales_channel_code,
                                        --KEY 'rqstshpdate' VALUE TO_CHAR (CAST ( (FROM_TZ (CAST (dha.REQUEST_SHIP_DATE AS TIMESTAMP), '+00:00') AT TIME ZONE (iop.TIMEZONE_CODE)) AS TIMESTAMP),'YYYY/MM/DD HH24:MI:SS'),
                                        KEY 'rqstshpdate' VALUE to_char(CAST((from_tz(CAST(dha.request_ship_date AS TIMESTAMP),'+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP),'YYYY-MM-DD'),
                                        KEY 'gblhierchytr' VALUE hop.attribute2,
                                        KEY 'custhrdprtyacctnbr' VALUE dheb.attribute_char4,
                                        KEY 'asnoutput' VALUE hcasd3.attribute14,
                                        KEY 'frttrmcde' VALUE flv.tag,
                                        KEY 'edilocationcode' VALUE hcasd3.ece_tp_location_code,
                                        KEY 'regtrtnnbr' VALUE zr.registration_number,
                                        --KEY 'carrieracctnbr' VALUE hca.CUST_ACCOUNT_NUMBER,
                                        --KEY 'cocattribute' VALUE hrp.RESPONSIBILITY_TYPE,
                                        KEY 'freighttermdef' VALUE msl.meaning,
                                        KEY 'saasfrttrmcde' VALUE wdd.freight_terms_code,
                                        KEY 'holdforwarehouseheader' VALUE dheb.attribute_char10,
                                        KEY 'marknumber' VALUE CONVERT(dheb.attribute_char1, 'AL32UTF8', 'WE8MSWIN1252'), --dheb.attribute_char1,
                                        --CON0001205-117414: Logic for bypassing UTF8 conversion issue in case of additional spaces
                                        KEY 'sitelanguage' VALUE flv2.meaning,
										/**********************************************************************************************************
                                                  ** Added as part of Order Attachment.CON0001205-47076
										***********************************************************************************************************/
                                        KEY 'custshipmethod' VALUE dheb1.attribute_char2,
                                        KEY 'orderattachment' VALUE REGEXP_REPLACE(TRIM(substr(fdt.description, 1, 1000)), '[^a-zA-Z0-9[:space:]:.*-@%#,$&''()^{}/!_+|;<>?]', ' '),
                                        KEY 'orderattachmenttitle' VALUE fad.category_name,
                                        KEY 'orderattachmenttitlewarehouse' VALUE REGEXP_REPLACE(TRIM(substr(fdt1.description, 1, 255)), '[^a-zA-Z0-9[:space:]:.*-@%#,$&''()^{}/!_+|;<>?]', ' '),
                                        KEY 'orderattachmenttitlebilloflading' VALUE REGEXP_REPLACE(TRIM(substr(fdt2.description, 1, 1000)), '[^a-zA-Z0-9[:space:]:.*-@%#,$&''()^{}/!_+|;<>?]', ' '),
										/**********************************************************************************************************
                                              ** Added as part of SCAC code logic
										***********************************************************************************************************/
                                        KEY 'scaccode' VALUE nvl(wc.attribute1, wc_default.attribute1),
                                        KEY 'nullshippingmethod' VALUE flv3.meaning,
                                        KEY 'asnordersource' VALUE hcasd3.attribute16,
                                        KEY 'sourceordersystem' VALUE dha.source_order_system,
                                        KEY 'sitenumber' VALUE dheb.attribute_char9,
                                        KEY 'shiptoedilocationcode' VALUE hcasd2.ece_tp_location_code,
                                        KEY 'partynumber' VALUE hp2.party_number,
                                        --KEY 'bscarrieraccountnumber' VALUE nvl(wc.ATTRIBUTE2, wc_default.ATTRIBUTE2),
                                        KEY 'bscarrieraccountnumber' VALUE(
											SELECT
												coalesce(
													(
														SELECT
															flv5.description
														FROM
															panduit_fnd_lookup_values_tbl flv5
														WHERE
																flv5.lookup_type = 'PANDUIT_INV_078_CARRIER_ACC'
															AND flv5.attribute2 = hp1.party_name
															AND flv5.attribute1 = iop.organization_code
															AND flv5.language = 'US'
                                                            AND flv5.enabled_flag = 'Y'
													),
													(
														SELECT
															flv6.description
														FROM
															panduit_fnd_lookup_values_tbl flv6
														WHERE
																flv6.lookup_type = 'PANDUIT_INV_078_CARRIER_ACC'
															AND flv6.attribute1 = iop.organization_code
															AND flv6.language = 'US'
                                                            AND flv6.enabled_flag = 'Y'
															AND flv6.attribute2 =(
																SELECT
																	coalesce(
																	(
																		SELECT
																			substr(flv1.attribute1,
																				   1,
																				   instr(flv1.attribute1, '-') - 1)
																		FROM
																			panduit_fnd_lookup_values_tbl flv1
																		WHERE
																				flv1.lookup_type = 'PANDUIT_OM_WMS_SHIP_MET_DEF'
																			AND flv1.tag = iop.organization_code
																			AND flv1.description = dha.order_type_code
																			AND flv1.language = 'US'
                                                                            AND flv1.enabled_flag  = 'Y'
																	),
																	(
																		SELECT
																			substr(flv2.attribute1,
																				   1,
																				   instr(flv2.attribute1, '-') - 1)
																		FROM
																			panduit_fnd_lookup_values_tbl flv2
																		WHERE
																				flv2.lookup_type = 'PANDUIT_OM_WMS_SHIP_MET_DEF'
																			AND flv2.tag = iop.organization_code
																			AND flv2.description = 'Default'
																			AND flv2.language = 'US'
                                                                            AND flv2.enabled_flag = 'Y'
																	),
																	(
																		SELECT
																			substr(flv3.attribute1,
																				   1,
																				   instr(flv3.attribute1, '-') - 1)
																		FROM
																			panduit_fnd_lookup_values_tbl flv3
																		WHERE
																				flv3.lookup_type = 'PANDUIT_OM_WMS_SHIP_MET_DEF'
																			AND flv3.language = 'US'
																			AND flv3.tag = 'Default'
																			AND flv3.description = 'Default'
																	))
																FROM
																	dual
															)
													)
												)
											FROM
												dual
										),
										/**********************************************************************************************************
                                        ** Added as part of defualt shipping method derived from lookup
										***********************************************************************************************************/
                                        KEY 'defaultshippingmethod' VALUE(
											SELECT
												coalesce((
													SELECT
														flv1.attribute1
													FROM
														panduit_fnd_lookup_values_tbl flv1
													WHERE
															flv1.lookup_type = 'PANDUIT_OM_WMS_SHIP_MET_DEF'
														AND flv1.tag = iop.organization_code
														AND flv1.description = dha.order_type_code
														AND flv1.language = 'US'
                                                        AND flv1.enabled_flag = 'Y'
												),(
													SELECT
														flv12.attribute1
													FROM
														panduit_fnd_lookup_values_tbl flv12
													WHERE
															flv12.lookup_type = 'PANDUIT_OM_WMS_SHIP_MET_DEF'
														AND flv12.tag = iop.organization_code
														AND flv12.description = 'Default'
														AND flv12.language = 'US'
                                                        AND flv12.enabled_flag = 'Y'
												),(
													SELECT
														flv3.attribute1
													FROM
														panduit_fnd_lookup_values_tbl flv3
													WHERE
															flv3.lookup_type = 'PANDUIT_OM_WMS_SHIP_MET_DEF'
														AND flv3.language = 'US'
														AND flv3.tag = 'Default'
														AND flv3.description = 'Default'
                                                        AND flv3.enabled_flag  = 'Y'
												))
											FROM
												dual
										),
										KEY 'customershipmethodparcel' VALUE hcasd3.ATTRIBUTE8, -- Changes done as part of CON0001205-100155
										KEY 'custshipscaccode' VALUE wc1.attribute1, -- Changes done as part of CON0001205-100155
                                        KEY 'lines' VALUE JSON_ARRAYAGG(
										JSON_OBJECT(
													KEY 'rcrdid' VALUE bt.record_id,
													KEY 'ord_qty' VALUE wdd.requested_quantity,
													KEY 'fulfillineid' VALUE dfla.fulfill_line_id,
													KEY 'lnnumber' VALUE dla.display_line_number,
													KEY 'statuscode' VALUE dla.status_code,
													KEY 'itemnum' VALUE esib.item_number,
													--KEY 'ordqty' VALUE dfla.ordered_qty,
													KEY 'ordlineqty' VALUE dfla.ordered_qty,
													KEY 'untlctprice' VALUE dla.unit_list_price,
													KEY 'untlslprice' VALUE dla.unit_selling_price,
													KEY 'orduom' VALUE dla.ordered_uom,
													KEY 'dlvrydtlid' VALUE wdd.delivery_detail_id,
													KEY 'schdshipdate' VALUE to_char(CAST((from_tz(CAST(dfla.schedule_ship_date AS TIMESTAMP),'+00:00') 
																				AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP),'YYYY-MM-DD'),
													KEY 'schdarrivaldate' VALUE to_char(CAST((from_tz(CAST(dfla.schedule_arrival_date AS TIMESTAMP),'+00:00') 
																					AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP),'YYYY-MM-DD'),
													KEY 'fulfilllinenbr' VALUE dfla.fulfill_line_number,
                                                    ---changes made by Mansi for sub_type:UPC and Military Spec Number :CON0001205-130795
													KEY 'upc' VALUE (select eirb.cross_reference from pdt_erp_datasync.panduit_egp_item_relationships_b_tbl eirb where
                                                    esib.inventory_item_id = eirb.inventory_item_id (+)
                                                    AND iop.master_organization_id = eirb.master_organization_id (+)
                                                    AND eirb.item_relationship_type (+) = 'ITEM_XREF'
                                                    AND eirb.sub_type (+) = 'UPC P/N'
                                                    order by last_update_date desc 
                                                    FETCH FIRST 1 ROW ONLY
                                                    ),
													KEY 'mltryspecnbr' VALUE	 (select eirb.cross_reference from pdt_erp_datasync.panduit_egp_item_relationships_b_tbl eirb where
                                                    esib.inventory_item_id = eirb.inventory_item_id (+)
                                                    AND iop.master_organization_id = eirb.master_organization_id (+)
                                                    AND eirb.item_relationship_type (+) = 'ITEM_XREF'
                                                    AND eirb.sub_type (+) = 'Military Spec Number'
                                                    order by last_update_date desc 
                                                    FETCH FIRST 1 ROW ONLY
                                                    ),

													KEY 'custpolinenbr' VALUE nvl(dfleb.attribute_char1, dfla.customer_po_line_number), --1.1 - Changes done as part of CON0001205-81784
													KEY 'omlinenbr' VALUE dla.line_number,
													KEY 'custponbr' VALUE dfla.customer_po_number,
													 ---------------------------------------------------------------------------------------------
													---Change as part of CR: CON0001205-104993
													KEY 'cocattribute' VALUE /*nvl(nvl(nvl(hrp.responsibility_type, hrp1.responsibility_type),
																					 hrp2.responsibility_type), hrp3.responsibility_type)*/
																			(
																				SELECT
																					hrp.responsibility_type
																				FROM
																					pdt_erp_datasync.panduit_hz_cust_acct_sites_tbl     hzcsuac1,
																					pdt_erp_datasync.panduit_hz_cust_account_roles_tbl  hcar,
																					pdt_erp_datasync.panduit_hz_role_responsibility_tbl hrp
																				WHERE
																						1 = 1
																					AND hzcsuac1.party_site_number = dheb.attribute_char9
																					AND hzcsuac1.site_use_code = 'SOLD_TO'
                                                                                    AND hzcsuac1.status = 'A' -- Added JIRA 133192
																					AND hzcsuac1.cust_account_site_id = hcar.cust_acct_site_id
																					AND hcar.primary_flag = 'Y'
																					AND hcar.cust_account_role_id = hrp.cust_account_role_id
																					AND hrp.responsibility_type IN ('COMP_CERTI_M', 'COMP_CERTI_MQ', 'COMP_CERTI_RQ', 'COMP_CERTI_R')
																				ORDER BY
																					hrp.last_update_date DESC,
																					hcar.last_update_date DESC
																				FETCH FIRST ROW ONLY
																			),
													----------------------------------------------------------------------------------------------
													KEY 'packinginstructions' VALUE dfla.packing_instructions,
													KEY 'custpartnbr' VALUE nvl(dfleb.attribute_char2, dfleb1.attribute_char4), --1.1 - Changes done as part of CON0001205-81784
													KEY 'holdforwarehouseline' VALUE dfleb1.attribute_char17,
													KEY 'uom' VALUE dfleb.attribute_char6,
													KEY 'uomconversionrate' VALUE dfleb1.attribute_number2,
													KEY 'lineid' VALUE dla.line_id,
													KEY 'sourcescheduleid' VALUE dla.source_schedule_id,
													KEY 'sourceschedulenumber' VALUE dla.source_schedule_number,
													KEY 'totalshipmentquantity' VALUE bt.attribute3
										RETURNING CLOB)
                                RETURNING CLOB)
                            RETURNING CLOB)  json1_object
                    FROM
                        panduit_doo_headers_all_tbl                           dha,
                        panduit_doo_lines_all_tbl                             dla,
                        panduit_doo_fulfill_lines_all_tbl                     dfla,
                        panduit_hz_parties_tbl                                hp,
                        panduit_hz_parties_tbl                                hp1,
                        panduit_doo_order_addresses_tbl                       doa,
                        panduit_doo_order_addresses_tbl                       doa2,
                        --panduit_hz_party_sites_tbl                          	hps,
                        panduit_hz_cust_acct_sites_tbl                        hcas,
                        panduit_hz_cust_acct_sites_tbl                        hcas2,
                        panduit_hz_cust_acct_sites_tbl                        hcas3,
                        panduit_hz_cust_acct_sites_tbl                        hcas4,
                        --panduit_hz_cust_acct_sites_tbl                      	hcas5,
                        panduit_hz_locations_tbl                              hl,
                        panduit_hz_locations_tbl                              h2,
                        panduit_hz_locations_tbl                              h3,
                        panduit_hz_locations_tbl                              h4,
                        pdt_erp_datasync.panduit_egp_system_items_b_tbl       esib,
                        --panduit_fnd_lookup_values_tbl 						FLV,
                        panduit_business_unit_tbl                             pbut,
                        panduit_om_so_to_wms_tbl                              bt,
                        pdt_erp_datasync.panduit_inv_org_parameters_tbl       iop,
                        pdt_erp_datasync.panduit_wsh_delivery_details_tbl     wdd,
                        pdt_erp_datasync.panduit_hz_organization_profiles_tbl hop,
                        panduit_doo_headers_eff_b_tbl                         dheb,
                        panduit_doo_headers_eff_b_tbl                         dheb1,
                       -- panduit_egp_item_relationships_b_tbl                  eirb,
                       -- panduit_egp_item_relationships_b_tbl                  eirb1,
                        panduit_cust_acct_sites_dff_tbl                       hcasd,
                        panduit_hz_cust_accounts_tbl                          hca,
                        panduit_hz_party_sites_tbl                            hps,
                        panduit_hz_party_sites_tbl                            hps1,
                        pdt_erp_datasync.panduit_msc_sr_lookup_values_vl_tbl  msl,
                        panduit_fnd_lookup_values_tbl                         flv,
                        panduit_fnd_lookup_values_tbl                         flv2,
                        pdt_erp_datasync.panduit_doo_fulfill_lines_eff_b_tbl  dfleb,
                        pdt_erp_datasync.panduit_doo_fulfill_lines_eff_b_tbl  dfleb1,
                        pdt_erp_datasync.panduit_zx_registrations_tbl         zr,
                        pdt_erp_datasync.panduit_zx_party_tax_profile_tbl     zptp,
                        pdt_erp_datasync.panduit_hz_cust_acct_sites_tbl       hzcsua,
                        --panduit_doo_headers_all_tbl 						    dha2,
                        --panduit_doo_lines_all_tbl                             dla2,
                        --panduit_doo_fulfill_lines_all_tbl                     dfla2,
                        --panduit_hz_parties_tbl hp2,
                        panduit_cust_acct_sites_dff_tbl                       hcasd2,
                        panduit_cust_acct_sites_dff_tbl                       hcasd3,
                        --PANDUIT_CUST_ACCT_SITES_DFF_TBL             		  	hcasd4,
                        --PANDUIT_HZ_PARTY_SITES_TBL                          	hps2,
                        pdt_erp_datasync.panduit_wsh_carriers_tbl             wc,
                        pdt_erp_datasync.panduit_wsh_carriers_tbl             wc_default,
						-- Added as part of CON0001205-47076 --start
                        (SELECT fad_inner.pk1_value,
                        fad_inner.document_id,
                        fad_inner.category_name
                        FROM (SELECT fad_x.pk1_value,
                        fad_x.document_id,
                        fad_x.category_name,
                        ROW_NUMBER() OVER (
                        PARTITION BY fad_x.pk1_value, fad_x.category_name
                        ORDER BY fdt_x.creation_date DESC, fad_x.attached_document_id DESC
                        ) rn
                        FROM pdt_erp_datasync.panduit_fnd_attached_documents_tbl fad_x,
                        pdt_erp_datasync.panduit_fnd_documents_tl_tbl       fdt_x
                        WHERE fad_x.document_id   = fdt_x.document_id
                        AND fdt_x.language      = 'US'
                        AND fad_x.category_name = 'PACKING SLIP'
                        ) fad_inner
                         WHERE fad_inner.rn = 1
                        )  fad,
                        pdt_erp_datasync.panduit_fnd_documents_tl_tbl         fdt,
                        pdt_erp_datasync.panduit_fnd_documents_tbl            fd,
                        (SELECT fad_inner.pk1_value,
                        fad_inner.document_id,
                        fad_inner.category_name
                        FROM (SELECT fad_x.pk1_value,
                        fad_x.document_id,
                        fad_x.category_name,
                        ROW_NUMBER() OVER (
                        PARTITION BY fad_x.pk1_value, fad_x.category_name
                        ORDER BY fdt_x.creation_date DESC, fad_x.attached_document_id DESC
                        ) rn
                        FROM pdt_erp_datasync.panduit_fnd_attached_documents_tbl fad_x,
                        pdt_erp_datasync.panduit_fnd_documents_tl_tbl       fdt_x
                        WHERE fad_x.document_id   = fdt_x.document_id
                        AND fdt_x.language      = 'US'
                        AND fad_x.category_name = 'WAREHOUSE MESSAGE'
                        ) fad_inner
                        WHERE fad_inner.rn = 1
                        )  fad1, --Added under JIRA CON0001205-125552
                        pdt_erp_datasync.panduit_fnd_documents_tl_tbl         fdt1,
                        pdt_erp_datasync.panduit_fnd_documents_tbl            fd1,
                        (SELECT fad_inner.pk1_value,
                        fad_inner.document_id,
                        fad_inner.category_name
                        FROM (SELECT fad_x.pk1_value,
                        fad_x.document_id,
                        fad_x.category_name,
                        ROW_NUMBER() OVER (
                        PARTITION BY fad_x.pk1_value, fad_x.category_name
                        ORDER BY fdt_x.creation_date DESC, fad_x.attached_document_id DESC
                        ) rn
                        FROM pdt_erp_datasync.panduit_fnd_attached_documents_tbl fad_x,
                        pdt_erp_datasync.panduit_fnd_documents_tl_tbl       fdt_x
                        WHERE fad_x.document_id   = fdt_x.document_id
                        AND fdt_x.language      = 'US'
                        AND fad_x.category_name = 'BILL OF LADING MESSAGE'
                        ) fad_inner
                        WHERE fad_inner.rn = 1
                        )  fad2,  -- Added under JIRA CON0001205-125552
                        pdt_erp_datasync.panduit_fnd_documents_tl_tbl         fdt2,
                        pdt_erp_datasync.panduit_fnd_documents_tbl            fd2,
						--Added as part of CON0001205-47076 --End
                        pdt_erp_datasync.panduit_hz_contact_points_tbl        hcp,
                        pdt_erp_datasync.panduit_hz_contact_points_tbl        hcp1,
						--------------------------------------------------------------
						---Ccommented as part of CR: CON0001205-104993
                        --pdt_erp_datasync.panduit_hz_cust_account_roles_tbl    hcar,
                        /*
						pdt_erp_datasync.panduit_hz_role_responsibility_tbl   hrp,
                        pdt_erp_datasync.panduit_hz_role_responsibility_tbl   hrp1,
                        pdt_erp_datasync.panduit_hz_role_responsibility_tbl   hrp2,
                        pdt_erp_datasync.panduit_hz_role_responsibility_tbl   hrp3,
						*/
                        --------------------------------------------------------------
                        panduit_fnd_lookup_values_tbl                         flv3,
                        panduit_hz_parties_tbl                                hp2,
                        panduit_hz_party_sites_tbl                            hps2,
                        panduit_hz_party_sites_tbl                            hps3,
                        panduit_hz_parties_tbl                                hp3,
                        --pdt_erp_datasync.panduit_hz_cust_accounts_tbl      	hca
                        pdt_erp_datasync.panduit_wsh_delivery_details_dff_tbl wshd,
                        --pdt_erp_datasync.panduit_hz_party_sites_tbl           hps5, 	--Added for change for CR CON0001205-92617
                        pdt_erp_datasync.panduit_hz_cust_acct_sites_tbl       hzcsua6,	--Added for change for CR CON0001205-92617
                        pdt_erp_datasync.panduit_hz_locations_tbl             h5,		--Added for change for CR CON0001205-92617
                        pdt_erp_datasync.panduit_hz_party_sites_tbl           hps6, 	--Added for change for CR CON0001205-92617
                        pdt_erp_datasync.panduit_wsh_carriers_tbl             wc1
                    WHERE
                            1 = 1
						AND bt.batch_number = p_batch_number                      
                        AND dha.header_id = dla.header_id
                        AND bt.order_number = dha.order_number
                        AND bt.order_line_number = dla.display_line_number
                        AND bt.business_unit_name = pbut.business_unit_name
                        AND bt.attribute1 = dfla.fulfill_line_id
                        AND bt.delivery_detail_id = wdd.delivery_detail_id --Added on 29/05/25
                        --  AND hca.party_id = hp.party_id
                        AND dfla.fulfill_org_id = iop.organization_id
                        AND pbut.business_unit_id = dha.org_id
                        AND dha.header_id = dfla.header_id
                        AND dfla.line_id = dla.line_id
                        AND dha.sold_to_party_id = hp.party_id
                         AND hp.status = 'A'
                        --AND esib.inventory_item_id = dla.inventory_item_id
                        AND esib.inventory_item_id = wdd.inventory_item_id
                        AND esib.organization_id = dla.inventory_organization_id
						/**********************************************************************************************************
							** Added as part of order address from header
						***********************************************************************************************************/
                        AND dha.header_id = doa.header_id (+)
                        AND doa.address_use_type (+) = 'BILL_TO'
                        AND doa.cust_acct_id = hca.cust_account_id (+)
                        AND hca.status (+) = 'A'
                        AND doa.cust_acct_site_use_id = hzcsua.site_use_id (+)
                        AND hzcsua.status (+) = 'A'
                        AND hzcsua.cust_account_site_id = hcas.cust_account_site_id (+)
                        AND hcas.site_use_code (+) = 'BILL_TO'
                        AND hcas.status (+) = 'A'
                        --AND hcas.party_site_id (+)= hps.party_site_id
                        --AND hps.party_site_id = hcas.party_site_id (+)
                        AND hps.location_id = hl.location_id (+)
                        AND hl.status_flag (+) = 'A'
                        AND dha.header_id = doa2.header_id (+)
                        AND doa2.party_site_id = hps1.party_site_id (+)
                        AND hps1.status (+) = 'A'
                        AND hps1.location_id = h2.location_id (+)
                        AND h2.status_flag (+) = 'A'
                        AND doa2.address_use_type (+) = 'SHIP_TO'
						/**********************************************************************************************************
							** End for order address from header
						***********************************************************************************************************/
                        --AND doa.header_id (+) = dha.header_id
                        --AND doa.address_use_type (+) = 'SHIP_TO'
                        --AND doa.party_site_id = hps.party_site_id (+)
                        --AND hcas.location_id = hl.location_id (+)
                        --AND hcas2.location_id = h2.location_id (+)
                        --AND doa1.header_id (+) = dha.header_id
                        --AND doa1.address_use_type (+) = 'BILL_TO'
                        --AND doa.party_id = doa1.party_id
                        AND dfla.shippable_flag = 'Y'
                        --AND dha.status_code = 'OPEN'
                        --AND dfla.status_code = 'AWAIT_SHIP'
                        --AND dfla.ON_HOLD = 'N'
                        AND wdd.carrier_id = hp1.party_id (+)
                        AND hp1.status (+) = 'A'
                        --AND dfla.fulfill_line_id = wdd.source_shipment_id (+) --21/4/25
                        --AND (dfla.fulfill_line_id = wdd.source_shipment_id or dfla.split_from_Fline_id = wdd.source_shipment_id)
                        --AND Nvl(dfla.split_from_fline_id, dfla.fulfill_line_id) = wdd.source_shipment_id
                        AND nvl(dfla.fulfillment_split_ref_id, dfla.fulfill_line_id) = wdd.source_shipment_id
                        --AND wdd.SOURCE_HEADER_ID (+) = dha.HEADER_ID
                        --AND wdd.SOURCE_LINE_ID (+) = dla.LINE_ID
                        --AND hcas.site_use_code (+) = 'BILL_TO'
                        --AND hcas2.site_use_code (+) = 'SHIP_TO'
                        --AND dfla.bill_to_site_use_id = hcas.site_use_id (+)
                        --AND dfla.ship_to_party_site_id = hcas2.account_site_party_site_id (+)
                        --AND dla.STATUS_CODE = 'Awaiting Shipping'
                        AND iop.organization_code IN (
                            SELECT
                                meaning
                            FROM
                                panduit_fnd_lookup_values_tbl
                            WHERE
                                    lookup_type = 'PND_WMS_ORGLOC_OSP'
                                AND language = 'US'
                        )
                        AND bt.status IN ( 'NEW', 'REPROCESS' )
                        AND hp.party_id = hop.party_id (+)
                        AND dha.header_id = dheb.header_id (+)
                        AND dheb.context_code (+) = 'Common'
-- Commented by Mansi for eirb and eirb1 tables under CON0001205-130795 Jira                 
--                        AND esib.inventory_item_id = eirb.inventory_item_id (+)
--                        AND iop.master_organization_id = eirb.master_organization_id (+)
--                        AND eirb.item_relationship_type (+) = 'ITEM_XREF'
--                        AND eirb.sub_type (+) = 'UPC P/N'
--                        AND esib.inventory_item_id = eirb1.inventory_item_id (+)
--                        AND iop.master_organization_id = eirb1.master_organization_id (+)
--                        AND eirb1.item_relationship_type (+) = 'ITEM_XREF'
--                        AND eirb1.sub_type (+) = 'Military Spec Number'
                        AND hp.party_id = hps.party_id (+)
                        AND hps.status (+) = 'A'
                        --AND hp.PARTY_ID = hca.PARTY_ID(+)
                        AND hps.party_site_id = hcasd.party_site_id (+)
                        --AND dfla.SHIP_TO_PARTY_SITE_ID = hps.party_site_id(+)
                        --AND hcas.location_id (+)= hps.LOCATION_ID
                        --AND hcas2.location_id (+)=hps.LOCATION_ID
                        --AND hca.CUST_ACCOUNT_ID = hcasd.CUST_ACCOUNT_ID(+)
                        --AND hca.CUST_ACCOUNT_ID=hcas.CUST_ACCOUNT_ID(+)
                        --AND hps.PARTY_SITE_ID = hcas.PARTY_SITE_ID(+)
						/**********************************************************************************************************
							** Added as part of Freigh term from order line
						***********************************************************************************************************/
                        AND dfla.freight_terms_code = msl.lookup_code (+)
                        AND msl.lookup_type (+) = 'WSH_FREIGHT_CHARGE_TERMS'
                        AND msl.meaning = flv.meaning (+)
                        AND flv.lookup_type (+) = 'WSH_FREIGHT_CHARGE_TERMS'
                        AND flv.language (+) = 'US'
                        AND flv.enabled_flag (+) = 'Y'
                        /*AND wdd.FREIGHT_TERMS_CODE = flv.LOOKUP_CODE(+)
                        AND flv.LOOKUP_TYPE (+)= 'WSH_FREIGHT_CHARGE_TERMS'
                        AND flv.LANGUAGE (+)= 'US'*/
						/**********************************************************************************************************
							** End for Freigh term from order line
						***********************************************************************************************************/
                        AND dfla.fulfill_line_id = dfleb.fulfill_line_id (+)
                        AND dfleb.context_code (+) = 'EDI'
                        AND dfla.fulfill_line_id = dfleb1.fulfill_line_id (+)
                        AND dfleb1.context_code (+) = 'Common'
                        AND hps.party_site_id = zptp.party_id (+)
                        AND zptp.party_tax_profile_id = zr.party_tax_profile_id (+)
                        AND hcas.party_site_id = hps.party_site_id (+)
                        ----------------------------------------------------------------
                        ---Ccommented as part of CR: CON0001205-104993
                        /*
						AND dha.sold_to_party_contact_id = hcar.relationship_id (+)
                        --AND hcar.PRIMARY_FLAG (+)= 'Y'
                        AND hcar.cust_account_role_id = hrp.cust_account_role_id (+)
                        AND hrp.responsibility_type (+) = 'COMP_CERTI_M'
                        AND hcar.cust_account_role_id = hrp1.cust_account_role_id (+)
                        AND hrp1.responsibility_type (+) = 'COMP_CERTI_MQ'
                        AND hcar.cust_account_role_id = hrp2.cust_account_role_id (+)
                        AND hrp2.responsibility_type (+) = 'COMP_CERTI_RQ'
                        AND hcar.cust_account_role_id = hrp3.cust_account_role_id (+)
                        AND hrp3.responsibility_type (+) = 'COMP_CERTI_R'
						*/
                        ------------------------------------------------------------
                        --AND    hps.party_site_id = hcas.party_site_id(+)
                        /*
						AND hcas.CUST_ACCOUNT_ID = hcar.CUST_ACCOUNT_ID(+)
                        AND hcar.CUST_ACCOUNT_ROLE_ID = hrp.CUST_ACCOUNT_ROLE_ID(+)
                        AND hrp.RESPONSIBILITY_TYPE (+) ='COMP_CERTI_M'
                        AND hrp.RESPONSIBILITY_TYPE (+) ='COMP_CERTI_MQ'
                        AND hrp.RESPONSIBILITY_TYPE (+) ='COMP_CERTI_RQ'
                        AND hrp.RESPONSIBILITY_TYPE (+) ='COMP_CERTI_R'
						*/
						/**********************************************************************************************************
							** Added as part of Site Number from order header dff
						***********************************************************************************************************/
                        /*
						AND dha.header_id = dha2.header_id(+)
                        AND dla.line_id = dla2.line_id(+)
                        AND dfla.header_id = dfla2.header_id(+)
                        AND dfla.line_id = dfla2.line_id(+)
                        --AND hp.party_id = hp2.party_id
						AND dha2.sold_to_party_id = hp2.party_id(+)
                        AND dha2.header_id = dfla2.header_id(+)
                        AND dfla2.line_id = dla2.line_id(+)
                        AND dha2.header_id = dla2.header_id(+)
                        AND hp2.PARTY_ID = hps2.PARTY_ID(+)
                        AND hps2.PARTY_SITE_ID = hcasd2.PARTY_SITE_ID(+)
                        AND dfla2.SHIP_TO_PARTY_SITE_ID = hps2.party_site_id(+)
						*/			
						/**********************************************************************************************************
							** End for Site Number from header dff
						***********************************************************************************************************/
						/**********************************************************************************************************
							** Added as part of Order Address from fulfillment line
						***********************************************************************************************************/
                        AND dfla.bill_to_site_use_id = hcas2.site_use_id (+)

                        AND dfla.ship_to_party_site_id = hcas3.account_site_party_site_id (+)
                        AND hcas2.location_id = h3.location_id (+)
                         AND h3.status_flag (+) = 'A'  -- Added by Abdul Shaik CON0001205-133192
                        AND hcas3.location_id = h4.location_id (+)
                        AND h4.status_flag (+) = 'A'  -- Added by Abdul Shaik CON0001205-133192
                        AND hcas2.site_use_code (+) = 'BILL_TO'
                        AND hcas2.status (+) = 'A' -- Added by Abdul Shaik CON0001205-133192
                        AND hcas3.site_use_code (+) = 'SHIP_TO'
                        AND hcas3.status (+) = 'A' --Added by Abdul Shaik CON0001205-133192
						/**********************************************************************************************************
							** End for Order Address from fulfillment line
						***********************************************************************************************************/
						/**********************************************************************************************************
							** Added as part of CON0001205-70268
						***********************************************************************************************************/
                        AND h4.location_id = hps2.location_id (+)
                        AND h3.location_id = hps3.location_id (+)
                        AND hps2.party_id = hp2.party_id (+)
                        AND hp2.status (+) = 'A'
                        AND hps3.party_id = hp3.party_id (+)
                        AND hp3.status (+) = 'A'
						/**********************************************************************************************************
							** End for CON0001205-70268
						***********************************************************************************************************/
                        AND dha.header_id = dheb1.header_id (+)
                        AND dheb1.context_code (+) = 'EDI3'
						/**********************************************************************************************************
                            ** Added as part of SCAC code logic
						***********************************************************************************************************/
                        AND wdd.carrier_id = wc.carrier_id (+)
                        AND wc_default.carrier_name (+) = 'FED'
                        AND dfla.ship_to_party_site_id = hps.party_site_id (+)
                        AND dfla.ship_to_party_site_id = hcasd2.party_site_id (+)
						/**********************************************************************************************************
                               ** Added as part of Order Attachment
						***********************************************************************************************************/
                        AND dha.header_id = fad.pk1_value (+)
                        AND fad.document_id = fdt.document_id (+)
                        AND fdt.language (+) = 'US'
                        AND fdt.document_id = fd.document_id (+)
                        AND fd.datatype_code (+) = 'TEXT'
                        AND fad.category_name (+) = 'PACKING SLIP'
                        --AND fdt.TITLE (+)= 'warehouse'
                        --AND dha.header_id = dha3.header_id
                        AND dha.header_id = fad1.pk1_value (+)
                        AND fad1.document_id = fdt1.document_id (+)
                        AND fdt1.language (+) = 'US'
                        AND fdt1.document_id = fd1.document_id (+)
                        AND fd1.datatype_code (+) = 'TEXT'
                        AND fad1.category_name (+) = 'WAREHOUSE MESSAGE'
                        AND dha.header_id = fad2.pk1_value (+)
                        AND fad2.document_id = fdt2.document_id (+)
                        AND fdt2.language (+) = 'US'
                        AND fdt2.document_id = fd2.document_id (+)
                        AND fd2.datatype_code (+) = 'TEXT'
                        AND fad2.category_name (+) = 'BILL OF LADING MESSAGE'
                        AND hcasd2.acct_site_language = flv2.lookup_code (+)
                        AND flv2.lookup_type (+) = 'PER_CORRESP_LANG'
                        AND flv2.language (+) = 'US'
                        AND flv2.enabled_flag (+) = 'Y'
						/*
						AND hca.CUST_ACCOUNT_ID = hcar.CUST_ACCOUNT_ID(+)
                        AND hcas.CUST_ACCOUNT_SITE_ID = hcar.CUST_ACCT_SITE_ID(+)
                        AND hcar.PRIMARY_FLAG (+)= 'Y'
						*/
                        AND dha.sold_to_party_contact_id = hcp.relationship_id (+)
                        AND hcp.contact_point_type (+) = 'EMAIL'
                        AND hcp.primary_flag (+) = 'Y'
                        AND hcp.status (+) = 'A' --CON0001205-116065
                        AND dha.sold_to_party_contact_id = hcp1.relationship_id (+)
                        AND hcp1.contact_point_type (+) = 'PHONE'
                        AND hcp1.primary_flag (+) = 'Y'
                        AND hcp1.status (+) = 'A' --CON0001205-116065
                        AND hp1.party_name = substr(flv3.meaning(+),1,instr(flv3.meaning(+), '-') - 1)
                        AND flv3.lookup_type (+) = 'PANDUIT_OM_DUMMY_SHIPPING_METH'
                        AND flv3.language (+) = 'US'
                        AND flv3.enabled_flag (+) = 'Y'
                        AND hcas4.site_use_id (+) = dheb.attribute_number1
                        AND hcas4.site_use_code (+) = 'SOLD_TO'
                        AND hcas4.status (+) = 'A'
                        AND hcasd3.cust_acct_site_id (+) = hcas4.cust_account_site_id
                        /*
						AND hcas5.site_use_id(+) = dheb.ATTRIBUTE_CHAR9
                        AND hcas5.site_use_code(+) = 'SHIP_TO'
                        AND hcas5.status(+) = 'A'
                        AND hcasd4.cust_acct_site_id(+) = hcas5.CUST_ACCOUNT_SITE_ID
						*/
                        --AND hps1.party_id = hp2.party_id
                        AND wdd.source_header_number = wshd.source_header_number
                        AND wshd.inventory_item_id = wdd.inventory_item_id
                        AND wshd.source_line_number = wdd.source_line_number
                        AND wshd.delivery_detail_id = wdd.delivery_detail_id
                        AND wshd.attribute13 IS NULL
                        AND upper(wshd.wms_interfaced_flag) = 'INTERFACED'
						/**********************************************************************************************************
							** Added as part of CON0001205-92617
						***********************************************************************************************************/
                        /*
						AND dheb.attribute_char9 = hps5.party_site_number (+)
                        AND hps5.location_id = h5.location_id (+)
                        and wdd.SHIP_TO_PARTY_SITE_ID=hps6.party_site_id(+)
						*/
                        AND dheb.attribute_number1 = hzcsua6.site_use_id (+)
                        AND hzcsua6.status (+) = 'A'
                        AND hzcsua6.location_id = h5.location_id (+)
                         AND h5.status_flag (+) = 'A'
                        AND wdd.ship_to_party_site_id = hps6.party_site_id (+)
                        AND hps6.status (+) = 'A'
						/**********************************************************************************************************
							** End for CON0001205-92617
						***********************************************************************************************************/
                        and wc1.carrier_name(+) = SUBSTR(hcasd3.ATTRIBUTE8,1, INSTR(hcasd3.ATTRIBUTE8,'-') - 1)
                    GROUP BY
                        dha.header_id,
                        iop.organization_code,
                        --p_oic_instance_id,
                        pbut.business_unit_name,
                        dha.source_order_system,
                        --dfla.fulfill_line_id,
                        dha.order_number,
                        dha.order_number,
                        dha.order_type_code,
                        dha.customer_po_number,
                        to_char(CAST((from_tz(CAST(dha.ordered_date AS TIMESTAMP),'+00:00') 
									AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP),'YYYY/MM/DD HH24:MI:SS'),
						/* 
						hl.address1,
                        hl.address2,
                        hl.address3,
                        hl.address4,
                        hl.postal_code,
                        hl.city,
                        hl.state,
                        hl.country,
                        hl.province,
                        h3.address1,
                        h3.address2,
                        h3.address3,
                        h3.address4,
                        h3.postal_code,
                        h3.city,
                        h3.state,
                        h3.country,
                        h3.province, 
						*/ --Commented for change for CR CON0001205-92617
                        h5.address1,
                        h5.address2,
                        h5.address3,
                        h5.address4,
                        h5.postal_code,
                        h5.city,
                        h5.state,
                        h5.country,
                        h5.province, --Commented for change for CR CON0001205-92617
                        h2.address1,
                        h2.address2,
                        h2.address3,
                        h2.address4,
                        h2.postal_code,
                        h2.city,
                        h2.state,
                        h2.country,
                        h4.address1,
                        h4.address2,
                        h4.address3,
                        h4.address4,
                        h4.postal_code,
                        h4.city,
                        h4.state,
                        h4.country,
                        hcp.email_address,
                        hcp1.phone_number,
                        dha.transactional_currency_code,
                        --dha.freight_terms_code,
                        dha.earliest_acceptable_ship_date,
                        dha.latest_acceptable_ship_date,
                        dha.packing_instructions,
                        dha.shipment_priority_code,
                        --hp.party_name, Commented for change for CR CON0001205-92617
                        hp.party_number,
                        wdd.mode_of_transport,
                        wdd.service_level,
                        hp1.party_name,
                        dha.order_type_code,
                        dha.sales_channel_code,
                        --TO_CHAR (CAST ( (FROM_TZ (CAST (dha.REQUEST_SHIP_DATE AS TIMESTAMP), '+00:00') AT TIME ZONE (iop.TIMEZONE_CODE)) AS TIMESTAMP),'YYYY/MM/DD HH24:MI:SS'),
                        to_char(CAST((from_tz(CAST(dha.request_ship_date AS TIMESTAMP),'+00:00') 
									AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP),'YYYY-MM-DD'),
                        hop.attribute2,
                        dheb.attribute_char4,
                        hcasd3.attribute14,
                        flv.tag,
                        msl.meaning,
                        hcasd3.ece_tp_location_code,
                        zr.registration_number,
                        --hca.CUST_ACCOUNT_NUMBER,
                        --hrp.RESPONSIBILITY_TYPE,
                        wdd.freight_terms_code,
                        dheb.attribute_char10,
                        dheb.attribute_char1,
                        dheb1.attribute_char2,
                        wc.attribute1,
                        wc.attribute2,
                        wc_default.attribute1,
                        wc_default.attribute2,
                        fdt.description,
                        fad.category_name,
                        fdt1.description,
                        fdt2.description,
                        flv2.meaning,
                        h2.province,
                        h4.province,
                        flv3.meaning,
                        hcasd3.attribute16,
                        dha.source_order_system,
                        dheb.attribute_char9,
                        hp2.party_name,
                        hcasd2.ece_tp_location_code,
                        hp2.party_number,
                        --hp3.party_name, --Commented for change for CR CON0001205-92617 
                        --iop.TIMEZONE_CODE,
                        bt.wmssoseqnum,
                        hzcsua6.party_site_name, --Added for change for CR CON0001205-92617
                        hps6.party_site_name, --Added for change for CR CON0001205-92617
                        hcasd3.ATTRIBUTE8,
						wc1.attribute1
                );

            p_status := 'SUCCESS';
        EXCEPTION
            WHEN OTHERS THEN
                p_status := 'ERROR';
                p_error_message := 'Error in fetching Data from Base tables'
                                   || sqlerrm
                                   || ' '
                                   || dbms_utility.format_error_backtrace;
                ROLLBACK;
        END;

        BEGIN
            UPDATE panduit_om_so_to_wms_tbl
            SET
                status = 'PROCESSING',
                child_integration_instance_id_1 = p_instance_id,
                last_update_date = CAST(systimestamp AS TIMESTAMP(3))
            WHERE
                    1 = 1
                AND status IN ( 'NEW', 'REPROCESS' )
				AND batch_number = p_batch_number;

            p_status := nvl(p_status,'SUCCESS');
        EXCEPTION
            WHEN OTHERS THEN
                p_status := 'ERROR';
                p_error_message := 'Error in Updating Data into PANDUIT_TRANSACTION_AUDIT'
                                   || sqlerrm
                                   || ' '
                                   || dbms_utility.format_error_backtrace;
                ROLLBACK;
        END;

        p_order_data := var_order_data;
    END panduit_get_order_for_wms_prc;

    PROCEDURE panduit_insert_rtv_osp_to_trx_aduit_prc (
        p_integration_name           IN VARCHAR2,
        p_integration_identifier     IN VARCHAR2,
        p_integration_version        IN VARCHAR2,
       -- p_instance_id                IN NUMBER,
        p_instance_id                IN VARCHAR2,
        p_invoked_by                 IN VARCHAR2,
        p_interface_rice_id          IN VARCHAR2,
        p_source                     IN VARCHAR2,
        p_target                     IN VARCHAR2,
        p_module                     IN VARCHAR2,
        p_last_run_datetime          IN VARCHAR2,
        p_integration_start_datetime IN VARCHAR2,
        p_status                     OUT VARCHAR2,
        p_error_message              OUT VARCHAR2
    ) IS
        l_cutoff_date VARCHAR2(200 BYTE);
    BEGIN
        BEGIN
            SELECT
                MAX(to_char(last_execute_time, 'YYYY-MM-DD"T"hh24:mi:ss.FF3'))
            INTO l_cutoff_date
            FROM
                panduit_last_run_timestamp_audit
            WHERE
                oic_integration_identifier = p_integration_identifier;

        EXCEPTION
            WHEN OTHERS THEN
                l_cutoff_date := '3000-01-01T00:00:00.000';
        END;

        BEGIN
            INSERT INTO panduit_om_so_to_wms_tbl (
                oic_instance_id,
                status,
                wmssonum,
                wmssoseqnum,
                last_update_date,
                creation_date,
                created_by,
                last_updated_by,
                order_number,
                order_line_number,
                request_payload,
                business_unit_name,
                rice_id,
                order_type,
                attribute1,
                attribute2,
                attribute3
            )
                (
                    SELECT
                        p_instance_id,
                        'NEW',
                        NULL,
                        /*nvl2(wdd.sales_order_number, wdd.sales_order_number, wdd.source_header_number)
                        || '-'
                        || wdd.source_line_number
                        || '-'
                        ||
                        (
                            SELECT
                                nvl(MAX(wmssoseqnum),
                                    0) + 1
                            FROM
                                panduit_om_so_to_wms_tbl
                            WHERE
                                order_number = wdd.sales_order_number
                        ),*/
                        (
                            SELECT
                                nvl(MAX(wmssoseqnum),
                                    0)
                            FROM
                                panduit_om_so_to_wms_tbl
                            WHERE
                                    order_number = wdd.sales_order_number
                                AND status = 'SUCCESS'
                        ),
                        sysdate,
                        sysdate,
                        NULL,
                        NULL,
                        wdd.sales_order_number,
                        wdd.source_line_number,
                        NULL,
                        NULL,
                        p_interface_rice_id,
                        wdd.source_line_type,
                        wdd.delivery_detail_id,
                        wdd.shipped_quantity,
                        wdd.source_shipment_number
                    FROM
                        pdt_erp_datasync.panduit_wsh_delivery_details_tbl wdd,
                          pdt_erp_datasync.panduit_wsh_delivery_details_dff_tbl wshd1 --Added on 02/09/25
                    WHERE
                            1 = 1
                          --Added on 02/09/25
                            AND wdd.source_header_number = wshd1.source_header_number
                                AND wdd.inventory_item_id = wshd1.inventory_item_id
                                AND wdd.source_line_number = wshd1.source_line_number
                                AND wdd.delivery_detail_id = wshd1.delivery_detail_id
                               and wshd1.attribute5 IS NULL --Shipment Line DFF 
                        --AND wdd.sales_order_number = 'US000573'
                        AND wdd.source_line_type IN ( 'OUTSIDE_PROCESSING', 'RETURN_TO_VENDOR' )
                        AND wdd.released_status = 'Y'
                      --  AND to_char(wdd.creation_date, 'YYYY-MM-DD"T"hh24:mi:ss.FF3') > ( l_cutoff_date ) commented on 02/09/25

                        AND NOT EXISTS (
                            SELECT
                                '1'
                            FROM
                                panduit_om_so_to_wms_tbl
                            WHERE
                                    order_number = wdd.sales_order_number
                                AND attribute1 = wdd.delivery_detail_id
                                AND status = 'SUCCESS'
                        )
                );

            p_status := 'SUCCESS';
        EXCEPTION
            WHEN OTHERS THEN
                p_status := 'ERROR';
                p_error_message := 'Error in fetching Data from Base tables '
                                   || sqlerrm
                                   || ' '
                                   || dbms_utility.format_error_backtrace;
                ROLLBACK;
        END;

    END panduit_insert_rtv_osp_to_trx_aduit_prc;

    PROCEDURE panduit_get_rtv_osp_from_trx_aduit_prc (
        p_instance_id            IN VARCHAR2,
        p_integration_identifier IN VARCHAR2,
        p_status                 OUT VARCHAR2,
        p_error_message          OUT VARCHAR2,
        p_order_data             OUT panduit_scm_fetch_source_order_for_wms_tab_typ
    ) AS

        var_order_data     panduit_scm_fetch_source_order_for_wms_tab_typ;
        var_order_data_out panduit_scm_fetch_source_order_for_wms_tab_typ;
        CURSOR c_process_records IS
        SELECT
            panduit_scm_fetch_source_order_for_wms_rec_typ(sales_order_number
                                                           || '-'
                                                           ||(wmssoseqnum + RANK()
                                                                            OVER(PARTITION BY sales_order_number
                                                                                 ORDER BY
                                                                                     ROWNUM
                                                                            )),
                                                           'null',
                                                           'null',
                                                           '{"WMSOrderNumber": "'
                                                           || sales_order_number
                                                           || '-'
                                                           ||(wmssoseqnum + RANK()
                                                                            OVER(PARTITION BY sales_order_number
                                                                                 ORDER BY
                                                                                     ROWNUM
                                                                            ))
                                                           || '",'
                                                           || substr(json1_object, 2))
                                                            --,dfla.fulfill_line_id,

        FROM
            (
                SELECT
                    wdd.sales_order_number,
                    'NULL',
                    'NULL',
                    bt.wmssoseqnum,
                    JSON_OBJECT(
                            KEY 'facility_code' VALUE iop.organization_code,
                                    KEY 'company_code' VALUE pbut.business_unit_name,
                                    KEY 'workordnbr' VALUE 'null',
                                    KEY 'ponbr' VALUE pha.segment1,
                                    KEY 'order_type' VALUE wdd.source_line_type,
                                    KEY 'ord_date' VALUE CAST((from_tz(CAST(wdd.creation_date AS TIMESTAMP),
                                                                       '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP),
                                    KEY 'req_ship_date' VALUE CAST((from_tz(CAST(wdd.date_requested AS TIMESTAMP),
                                                                            '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP),
                                    KEY 'cust_name' VALUE hp.party_name,
                                    KEY 'cust_addr' VALUE psav.address1,
                                    KEY 'cust_addr2' VALUE psav.address2,
                                    KEY 'cust_addr3' VALUE psav.address3,
                                    KEY 'btaddress4' VALUE psav.address4,
                                    KEY 'cust_zip' VALUE psav.postal_code,
                                    KEY 'cust_city' VALUE psav.city,
                                    KEY 'cust_state' VALUE psav.state,
                                    KEY 'cust_country' VALUE psav.country,
                                    KEY 'btprovince' VALUE psav.province,
                                    KEY 'mdeoftranprt' VALUE wdd.mode_of_transport,
                                    KEY 'srvclvl' VALUE wdd.service_level,
                                    KEY 'carrier' VALUE hp1.party_name,
                                                                      --updated as part of CON0001205-50833
                                                                    ---KEY 'payment_method' VALUE flv1.tag,
                                    KEY 'payment_method' VALUE rt.attribute1,
                                    KEY 'currency_code' VALUE wdd.currency_code,
                                    KEY 'sched_ship_date' VALUE CAST((from_tz(CAST(wdd.date_scheduled AS TIMESTAMP),
                                                                              '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP
                                                                              ),
                                    KEY 'ordnum' VALUE bt.wmssonum,
                                    KEY 'ship_via_code' VALUE flv.description,
                                                              /*KEY 'staddress1' VALUE h2.address1,
                                                               KEY 'staddress2' VALUE h2.address2,
                                                              KEY 'staddress3' VALUE h2.address3,
                                                              KEY 'staddress4' VALUE h2.address4,
                                                               KEY 'stpstlcde' VALUE h2.postal_code,
                                                               KEY 'stcity' VALUE h2.city,
                                                               KEY 'ststate' VALUE h2.state,
                                                               KEY 'stcountry' VALUE h2.country,
                                                                KEY 'stprovince' VALUE psav.PROVINCE,*/

                                    KEY 'lines' VALUE JSON_ARRAYAGG(
                                JSON_OBJECT(
                                    KEY 'rcrdid' VALUE bt.record_id,
                                    KEY 'ord_qty' VALUE wdd.requested_quantity,
                                    KEY 'cust_number_1' VALUE pla.line_num,
                                    KEY 'ship_request_line' VALUE wdd.delivery_detail_id,
                                    KEY 'uom_code' VALUE pla.uom_code,
                                            KEY 'qtyperprdct' VALUE 'null',
                                    KEY 'basistype' VALUE 'null',
                                    KEY 'spplytype' VALUE 'null',
                                    KEY 'itemnbr' VALUE esib.item_number,
                                    KEY 'compntitemnbr' VALUE 'null',
                                            KEY 'matrlseqnbr' VALUE pla.line_num,
                                    KEY 'ospsrvflag' VALUE outside_process_service_flag,
                                    KEY 'WOSeqNbr' VALUE wdd.sales_order_line_number,
                                    KEY 'maxtolerancepercentage' VALUE flv2.description
                                RETURNING CLOB)
                            RETURNING CLOB)
                        RETURNING CLOB)
                    json1_object
                FROM
                    panduit_po_headers_tbl                            pha,
                    panduit_po_lines_tbl                              pla,
                    pdt_erp_datasync.panduit_egp_system_items_b_tbl   esib,
                    pdt_erp_datasync.panduit_inv_org_parameters_tbl   iop,
                    pdt_erp_datasync.panduit_po_line_locations_tbl    ploc,
                    panduit_business_unit_tbl                         pbut,
                    pdt_erp_datasync.panduit_wsh_delivery_details_tbl wdd,
                    panduit_hz_parties_tbl                            hp,
                    panduit_hz_party_sites_tbl                        hps,
                    panduit_poz_suppliers_tbl                         ps,
                    panduit_poz_supplier_address_v_tbl                psav,
                    panduit_hz_parties_tbl                            hp1,
                    panduit_om_so_to_wms_tbl                          bt,
                    panduit_fnd_lookup_values_tbl                     flv,
          --  panduit_fnd_lookup_values_tbl                     flv1,
                    panduit_fnd_lookup_values_tbl                     flv2,
                    panduit_rcv_shipment_lines_tbl                    rsl,
                    panduit_rcv_transactions_tbl                      rt
                WHERE
                        1 = 1

                 --AND bt.order_number = pha.segment1
                    AND pha.po_header_id = pla.po_header_id
                    AND pla.item_id = esib.inventory_item_id
                    AND iop.master_organization_id = esib.organization_id
                    AND pla.po_line_id = ploc.po_line_id
                    AND ploc.ship_to_organization_id = iop.organization_id
                    AND pha.billto_bu_id = pbut.business_unit_id
                    AND pla.item_id = wdd.inventory_item_id
                    AND pha.segment1 = wdd.source_header_number
             --AND wdd.source_line_number = bt.ORDER_LINE_NUMBER
                    AND wdd.sales_order_number = bt.order_number
                    AND bt.attribute1 = wdd.delivery_detail_id
                    AND hp.party_id = hps.party_id
                    AND hp.party_id = ps.party_id
                    AND ps.vendor_id = pha.vendor_id
                    AND hps.party_id = psav.party_id
                    AND hps.party_site_id = psav.party_site_id
                    AND hps.location_id = psav.location_id
                    AND psav.last_update_date = (
                        SELECT
                            MAX(last_update_date)
                        FROM
                            panduit_poz_supplier_address_v_tbl
                        WHERE
                            party_id = psav.party_id
                    )
                    AND wdd.carrier_id = hp1.party_id (+)
                    AND wdd.source_line_type = 'RETURN_TO_VENDOR'
                    AND iop.organization_code IN (
                        SELECT
                            meaning
                        FROM
                            panduit_fnd_lookup_values_tbl
                        WHERE
                                lookup_type = 'PND_WMS_ORGLOC_OSP'
                            AND language = 'US'
                    )
                    AND iop.organization_code = flv.lookup_code (+)
                    AND flv.lookup_type (+) = 'PANDUIT_INV_SPK-I-404_SHIPMETH'
                    AND flv.language (+) = 'US'
                    AND flv.enabled_flag (+) = 'Y' --Added by Abdul
            /*AND pha.freight_terms_lookup_code = flv1.lookup_code (+)
            AND flv1.lookup_type (+)= 'FREIGHT TERMS'
            AND flv1.language (+)= 'US'*/

             /**********************************************************************************************************
                               ** Added as part of Freight Term in DFF for jira CON0001205-50833

             ***********************************************************************************************************/
                    AND rsl.po_header_id = pha.po_header_id
                    AND rsl.po_line_id = pla.po_line_id
                    AND wdd.sales_order_shipment_number = rt.transaction_id
                    AND rsl.shipment_header_id = rt.shipment_header_id
                    AND rsl.shipment_line_id = rt.shipment_line_id
                    AND rt.transaction_type = 'RETURN TO VENDOR'
                    AND rt.attribute_category = 'Freightterm'
             /**********************************************************************************************************
                               ** Added as part of Freight Term in DFF for jira CON0001205-50833

             ***********************************************************************************************************/
                    AND bt.status IN ( 'NEW', 'REPROCESS' )
                    AND bt.rice_id = 'SPK-I-404'
                    AND iop.organization_code = flv2.lookup_code (+)
                    AND flv2.lookup_type (+) = 'PANDUIT_INV_SPK-I-404-SHIP_TOL'
                    AND flv2.language (+) = 'US'
                     AND flv2.enabled_flag (+) = 'Y' -- Added by Abdul Shaik
            --AND wdd.sales_order_number = 'US000573'
                GROUP BY
                    iop.organization_code,
                    pbut.business_unit_name,
            --esib.item_number,
                    pha.segment1,
                    wdd.source_line_type,
                    CAST((from_tz(CAST(wdd.creation_date AS TIMESTAMP),
                                  '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP),
                    CAST((from_tz(CAST(wdd.date_requested AS TIMESTAMP),
                                  '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP),
                    hp.party_name,
                    psav.address1,
                    psav.address2,
                    psav.address3,
                    psav.address4,
                    psav.postal_code,
                    psav.city,
                    psav.state,
                    psav.country,
                    psav.province,
                    wdd.mode_of_transport,
                    wdd.service_level,
                    hp1.party_name,
            --flv1.tag,
                    rt.attribute1,
                    wdd.currency_code,
                    CAST((from_tz(CAST(wdd.date_scheduled AS TIMESTAMP),
                                  '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP),
                    bt.wmssonum,
                    flv.description,
                    wdd.sales_order_number,
            --iop.TIMEZONE_CODE,
                    bt.wmssoseqnum
                UNION ALL
                SELECT
                    wdd.sales_order_number,
                    'NULL',
                    'NULL',
                    bt.wmssoseqnum,
                    JSON_OBJECT(
                            KEY 'facility_code' VALUE iop.organization_code,
                                    KEY 'company_code' VALUE pbut.business_unit_name,
                                    KEY 'workordnbr' VALUE wwob.work_order_number,
                                    KEY 'ponbr' VALUE pha.segment1,
                                    KEY 'order_type' VALUE wdd.source_line_type,
                                    KEY 'ord_date' VALUE CAST((from_tz(CAST(wdd.creation_date AS TIMESTAMP),
                                                                       '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP),
                                    KEY 'req_ship_date' VALUE CAST((from_tz(CAST(wdd.date_requested AS TIMESTAMP),
                                                                            '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP),
                                    KEY 'cust_name' VALUE hp.party_name,
                                    KEY 'cust_addr' VALUE psav.address1,
                                    KEY 'cust_addr2' VALUE psav.address2,
                                    KEY 'cust_addr3' VALUE psav.address3,
                                    KEY 'btaddress4' VALUE psav.address4,
                                    KEY 'cust_zip' VALUE psav.postal_code,
                                    KEY 'cust_city' VALUE psav.city,
                                    KEY 'cust_state' VALUE psav.state,
                                    KEY 'cust_country' VALUE psav.country,
                                    KEY 'btprovince' VALUE psav.province,
                                    KEY 'mdeoftranprt' VALUE wdd.mode_of_transport,
                                    KEY 'srvclvl' VALUE wdd.service_level,
                                    KEY 'carrier' VALUE hp1.party_name,
                                                                       --updated as part of CON0001205-50833
                                    KEY 'payment_method' VALUE flv1.tag,
                                                                       --KEY 'payment_method' VALUE rt.attribute1,
                                    KEY 'currency_code' VALUE wdd.currency_code,
                                    KEY 'sched_ship_date' VALUE CAST((from_tz(CAST(wdd.date_scheduled AS TIMESTAMP),
                                                                              '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP
                                                                              ),
                                    KEY 'ordnum' VALUE bt.wmssonum,
                                    KEY 'ship_via_code' VALUE flv.description,
                                    KEY 'lines' VALUE JSON_ARRAYAGG(
                                JSON_OBJECT(
                                    KEY 'rcrdid' VALUE bt.record_id,
                                    KEY 'ord_qty' VALUE wdd.requested_quantity,
                                    KEY 'cust_number_1' VALUE pla.line_num,
                                    KEY 'ship_request_line' VALUE wdd.delivery_detail_id,
                                    KEY 'uom_code' VALUE pla.uom_code,
                                            KEY 'qtyperprdct' VALUE 'null',
                                    KEY 'basistype' VALUE 'null',
                                    KEY 'spplytype' VALUE 'null',
                                    KEY 'itemnbr' VALUE esib.item_number,
                                    KEY 'compntitemnbr' VALUE 'null',
                                            KEY 'matrlseqnbr' VALUE '1',
                                    KEY 'ospsrvflag' VALUE outside_process_service_flag,
                                    KEY 'WOSeqNbr' VALUE wdd.sales_order_line_number,
                                    KEY 'maxtolerancepercentage' VALUE flv2.description
                                                                                                            --KEY 'headerod' VALUE pha.po_header_id
                                RETURNING CLOB)
                            RETURNING CLOB)
                        RETURNING CLOB)
                    json1_object
                FROM
                    panduit_wie_work_orders_b_tbl                           wwob,
                    panduit_wie_wo_operations_b_tbl                         wwopb,
                    pdt_erp_datasync.panduit_egp_system_items_b_tbl         esib,
                    pdt_erp_datasync.panduit_wsh_delivery_details_tbl       wdd,
                    panduit_po_headers_tbl                                  pha,
                    panduit_hz_parties_tbl                                  hp,
                    panduit_hz_party_sites_tbl                              hps,
                    panduit_poz_suppliers_tbl                               ps,
                    panduit_poz_supplier_address_v_tbl                      psav,
                    panduit_hz_parties_tbl                                  hp1,
                    panduit_po_lines_tbl                                    pla,
--pdt_erp_datasync.panduit_egp_system_items_b_tbl    esib,
                    pdt_erp_datasync.panduit_inv_org_parameters_tbl         iop,
                    pdt_erp_datasync.panduit_po_line_locations_tbl          ploc,
                    panduit_business_unit_tbl                               pbut,
                    pdt_erp_datasync.panduit_wie_wo_operation_materials_tbl wwom,
                    panduit_om_so_to_wms_tbl                                bt,
                    panduit_fnd_lookup_values_tbl                           flv,
                    panduit_fnd_lookup_values_tbl                           flv1,
                    panduit_fnd_lookup_values_tbl                           flv2
            --panduit_rcv_shipment_lines_tbl                          rsl,
             --panduit_rcv_transactions_tbl                             rt
                WHERE
                        1 = 1
                --AND bt.order_number = wdd.sales_order_number
                --AND bt.order_number = wwob.WORK_ORDER_NUMBER
                    AND wwob.work_order_id = wwopb.work_order_id
                    AND esib.inventory_item_id = wwopb.osp_item_id
                    AND esib.organization_id = wwopb.organization_id
                    AND wdd.sales_order_line_number = wwopb.operation_seq_number
                    AND wdd.sales_order_number = wwob.work_order_number
                    AND wdd.sales_order_number = bt.order_number
             --AND wdd.source_line_number = bt.ORDER_LINE_NUMBER
                    AND bt.attribute1 = wdd.delivery_detail_id
                    AND esib.inventory_item_id = wdd.inventory_item_id
                    AND esib.organization_id = wdd.organization_id
                    AND wdd.source_header_number = pha.segment1
                    AND hp.party_id = hps.party_id
                    AND hp.party_id = ps.party_id
                    AND ps.vendor_id = pha.vendor_id
                    AND hps.party_id = psav.party_id
                    AND hps.party_site_id = psav.party_site_id
                    AND hps.location_id = psav.location_id
                    AND psav.last_update_date = (
                        SELECT
                            MAX(last_update_date)
                        FROM
                            panduit_poz_supplier_address_v_tbl
                        WHERE
                            party_id = psav.party_id
                    )
                    AND wdd.carrier_id = hp1.party_id (+)
                    AND pha.po_header_id = pla.po_header_id
                    AND pla.item_id = esib.inventory_item_id
                    AND esib.organization_id = iop.organization_id
                    AND pla.po_line_id = ploc.po_line_id
                    AND ploc.ship_to_organization_id = iop.organization_id
                    AND pha.billto_bu_id = pbut.business_unit_id
                    AND wwom.wo_operation_id (+) = wwopb.wo_operation_id
             --AND wwob.work_order_id = wwom.work_order_id
                    AND wwom.wo_operation_id IS NULL
                    AND wdd.source_line_type = 'OUTSIDE_PROCESSING'
                    AND iop.organization_code IN (
                        SELECT
                            meaning
                        FROM
                            panduit_fnd_lookup_values_tbl
                        WHERE
                                lookup_type = 'PND_WMS_ORGLOC_OSP'
                            AND language = 'US'
                    )
                    AND iop.organization_code = flv.lookup_code (+)
                    AND flv.lookup_type (+) = 'PANDUIT_INV_SPK-I-404_SHIPMETH'
                    AND flv.language (+) = 'US'
                    AND pha.freight_terms_lookup_code = flv1.lookup_code (+)
                    AND flv1.lookup_type (+) = 'FREIGHT TERMS'
                    AND flv1.language (+) = 'US'
                    AND flv1.enabled_flag (+) = 'Y'
            /*AND rsl.po_header_id = pha.po_header_id
            AND rsl.po_line_id = pla.po_line_id
            AND wdd.sales_order_shipment_number=rt.transaction_id
            AND rsl.shipment_header_id = rt.shipment_header_id
            AND rsl.shipment_line_id = rt.shipment_line_id
            AND rt.attribute_category = 'Freightterm'
            AND rt.transaction_type='OUTSIDE_PROCESSING'*/
                    AND bt.status IN ( 'NEW', 'REPROCESS' )
                    AND bt.rice_id = 'SPK-I-404'
                    AND iop.organization_code = flv2.lookup_code (+)
                    AND flv2.lookup_type (+) = 'PANDUIT_INV_SPK-I-404-SHIP_TOL'
                    AND flv2.language (+) = 'US'
                    AND flv2.enabled_flag (+) = 'Y'
--AND wwob.WORK_ORDER_NUMBER IN('LP-10000071','LP-10000070')
--AND wdd.sales_order_number = 'LP-10000094'
                GROUP BY
                    wwob.work_order_number,
            --esib.item_number,
                    pha.segment1,
                    wdd.source_line_type,
                    CAST((from_tz(CAST(wdd.creation_date AS TIMESTAMP),
                                  '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP),
                    CAST((from_tz(CAST(wdd.date_requested AS TIMESTAMP),
                                  '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP),
                    hp.party_name,
                    psav.address1,
                    psav.address2,
                    psav.address3,
                    psav.address4,
                    psav.postal_code,
                    psav.city,
                    psav.state,
                    psav.country,
                    psav.province,
                    wdd.mode_of_transport,
                    wdd.service_level,
                    hp1.party_name,
                    flv1.tag,
            --rt.attribute1,
                    wdd.currency_code,
                    CAST((from_tz(CAST(wdd.date_scheduled AS TIMESTAMP),
                                  '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP),
                    iop.organization_code,
                    pbut.business_unit_name,
                    bt.wmssonum,
                    flv.description,
                    wdd.sales_order_number,
             --iop.TIMEZONE_CODE,
                    bt.wmssoseqnum


--esib1.item_number
                UNION ALL
                SELECT
                    sales_order_number,
                    'NULL',
                    'NULL',
                    wmssoseqnum,
                    JSON_OBJECT(
                            KEY 'facility_code' VALUE organization_code,
                                    KEY 'company_code' VALUE business_unit_name,
                                    KEY 'workordnbr' VALUE work_order_number,
                                    KEY 'ponbr' VALUE segment1,
                                    KEY 'order_type' VALUE source_line_type,
                                    KEY 'ord_date' VALUE creation_date,
                                    KEY 'req_ship_date' VALUE date_requested,
                                    KEY 'cust_name' VALUE party_name1,
                                    KEY 'cust_addr' VALUE address1,
                                    KEY 'cust_addr2' VALUE address2,
                                    KEY 'cust_addr3' VALUE address3,
                                    KEY 'btaddress4' VALUE address4,
                                    KEY 'cust_zip' VALUE postal_code,
                                    KEY 'cust_city' VALUE city,
                                    KEY 'cust_state' VALUE state1,
                                    KEY 'cust_country' VALUE country,
                                    KEY 'btprovince' VALUE province,
                                    KEY 'mdeoftranprt' VALUE mode_of_transport,
                                    KEY 'srvclvl' VALUE service_level,
                                    KEY 'carrier' VALUE party_name,
                                    KEY 'payment_method' VALUE tag1,
                                    KEY 'currency_code' VALUE currency_code,
                                    KEY 'sched_ship_date' VALUE date_scheduled,
                                    KEY 'ordnum' VALUE wmssonum,
                                    KEY 'ship_via_code' VALUE description1,
                                    KEY 'lines' VALUE JSON_ARRAYAGG(
                                JSON_OBJECT(
                                    KEY 'rcrdid' VALUE record_id,
                                    KEY 'ord_qty' VALUE requested_quantity,
                                    KEY 'cust_number_1' VALUE line_num,
                                    KEY 'ship_request_line' VALUE delivery_detail_id,
                                    KEY 'uom_code' VALUE uom_code,
                                            KEY 'qtyperprdct' VALUE quantity_per_product,
                                    KEY 'basistype' VALUE basis_type,
                                    KEY 'spplytype' VALUE supply_type,
                                    KEY 'itemnbr' VALUE item_number,
                                    KEY 'compntitemnbr' VALUE compitemnum,
                                            KEY 'matrlseqnbr' VALUE material_seq_number,
                                    KEY 'ospsrvflag' VALUE outside_process_service_flag,
                                    KEY 'WOSeqNbr' VALUE sales_order_line_number,
                                    KEY 'maxtolerancepercentage' VALUE description
                                RETURNING CLOB)
                            RETURNING CLOB)
                        RETURNING CLOB)
                    json1_object
                FROM
                    (
                        SELECT DISTINCT
                            sales_order_number,
                            wmssoseqnum,
                            iop.organization_code,
                            pbut.business_unit_name,
                            wwob.work_order_number,
                            pha.segment1,
                            wdd.source_line_type,
                            CAST((from_tz(CAST(wdd.creation_date AS TIMESTAMP),
                                          '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP) creation_date,
                            CAST((from_tz(CAST(wdd.date_requested AS TIMESTAMP),
                                          '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP) date_requested,
                            hp.party_name                                            party_name1,
                            psav.address1,
                            psav.address2,
                            psav.address3,
                            psav.address4,
                            psav.postal_code,
                            psav.city,
                            psav.state                                               state1,
                            psav.country,
                            psav.province,
                            wdd.mode_of_transport,
                            wdd.service_level,
                            hp1.party_name,
                                                                       --updated as part of CON0001205-50833
                            flv1.tag                                                 tag1,
                                                                       --rt.attribute1 tag1,
                            wdd.currency_code,
                            CAST((from_tz(CAST(wdd.date_scheduled AS TIMESTAMP),
                                          '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP) date_scheduled,
                            bt.wmssonum,
                            flv.description                                          description1,
                            bt.record_id,
                            wdd.requested_quantity,
                            pla.line_num,
                            wdd.delivery_detail_id,
                            pla.uom_code,
                            NULL                                                     quantity_per_product,
                            wwom.basis_type,
                            'null'                                                   supply_type,
                            esib.item_number,
                            'null'                                                   compitemnum,
                            pla.line_num                                             material_seq_number,
                            esib.outside_process_service_flag,
                            wdd.sales_order_line_number,
                            flv2.description
                        FROM
                            panduit_wie_work_orders_b_tbl                           wwob,
                            panduit_wie_wo_operations_b_tbl                         wwopb,
                            pdt_erp_datasync.panduit_egp_system_items_b_tbl         esib,
                            pdt_erp_datasync.panduit_egp_system_items_b_tbl         esib1,
                            pdt_erp_datasync.panduit_wsh_delivery_details_tbl       wdd,
                            panduit_po_headers_tbl                                  pha,
                            panduit_hz_parties_tbl                                  hp,
                            panduit_hz_party_sites_tbl                              hps,
                            panduit_poz_suppliers_tbl                               ps,
                            panduit_poz_supplier_address_v_tbl                      psav,
                            panduit_hz_parties_tbl                                  hp1,
                            panduit_po_lines_tbl                                    pla,
                            pdt_erp_datasync.panduit_wie_wo_operation_materials_tbl wwom,
                            panduit_wis_work_centers_b_tbl                          wwcb,
                            panduit_wis_work_centers_b_tbl                          wwcb1,
--pdt_erp_datasync.panduit_egp_system_items_b_tbl    esib,
                            pdt_erp_datasync.panduit_inv_org_parameters_tbl         iop,
                            pdt_erp_datasync.panduit_po_line_locations_tbl          ploc,
                            panduit_business_unit_tbl                               pbut,
                            panduit_om_so_to_wms_tbl                                bt,
                            panduit_fnd_lookup_values_tbl                           flv,
                            panduit_fnd_lookup_values_tbl                           flv1,
                            panduit_fnd_lookup_values_tbl                           flv2
             --panduit_rcv_shipment_lines_tbl                          rsl,
             --panduit_rcv_transactions_tbl                             rt
                        WHERE
                                1 = 1
                            AND bt.order_number = wdd.sales_order_number
                            AND bt.attribute1 = wdd.delivery_detail_id
                --AND bt.order_number = wwob.WORK_ORDER_NUMBER
                            AND wwob.work_order_id = wwopb.work_order_id
                            AND esib.inventory_item_id = wwopb.osp_item_id
                            AND esib.organization_id = wwopb.organization_id
                            AND wdd.sales_order_number = wwob.work_order_number
            --AND wdd.sales_order_number = bt.order_number
             --AND wdd.source_line_number = bt.ORDER_LINE_NUMBER
                            AND esib.inventory_item_id = wdd.inventory_item_id
                            AND esib.organization_id = wdd.organization_id
                            AND wdd.sales_order_line_number = wwopb.operation_seq_number
                            AND wdd.source_header_number = pha.segment1
                            AND hp.party_id = hps.party_id
                            AND hp.party_id = ps.party_id
                            AND ps.vendor_id = pha.vendor_id
                            AND hps.party_id = psav.party_id
                            AND hps.party_site_id = psav.party_site_id
                            AND hps.location_id = psav.location_id
                            AND psav.last_update_date = (
                                SELECT
                                    MAX(last_update_date)
                                FROM
                                    panduit_poz_supplier_address_v_tbl
                                WHERE
                                    party_id = psav.party_id
                            )
                            AND wdd.carrier_id = hp1.party_id (+)
                            AND pha.po_header_id = pla.po_header_id
                            AND pla.item_id = esib.inventory_item_id
                            AND esib.organization_id = iop.organization_id
                            AND pla.po_line_id = ploc.po_line_id
                            AND ploc.ship_to_organization_id = iop.organization_id
                            AND pha.billto_bu_id = pbut.business_unit_id
                            AND wdd.source_line_type = 'OUTSIDE_PROCESSING'
                            AND iop.organization_code IN (
                                SELECT
                                    meaning
                                FROM
                                    panduit_fnd_lookup_values_tbl
                                WHERE
                                        lookup_type = 'PND_WMS_ORGLOC_OSP'
                                    AND language = 'US'
                            )
                            AND iop.organization_code = flv.lookup_code (+)
                            AND flv.lookup_type (+) = 'PANDUIT_INV_SPK-I-404_SHIPMETH'
                            AND flv.language (+) = 'US'
                            AND flv.enabled_flag (+) = 'Y'
                            AND pha.freight_terms_lookup_code = flv1.lookup_code (+)
                            AND flv1.lookup_type (+) = 'FREIGHT TERMS'
                            AND flv1.language (+) = 'US'
                            AND flv1.enabled_flag (+) = 'Y'
            /*AND rsl.po_header_id = pha.po_header_id
            AND rsl.po_line_id = pla.po_line_id
            AND wdd.sales_order_shipment_number=rt.transaction_id
            AND rsl.shipment_header_id = rt.shipment_header_id
            AND rsl.shipment_line_id = rt.shipment_line_id
            AND rt.attribute_category = 'Freightterm'
            AND rt.transaction_type='OUTSIDE_PROCESSING'*/
                            AND bt.status IN ( 'NEW', 'REPROCESS' )
                            AND bt.rice_id = 'SPK-I-404'
                            AND wwob.work_order_id = wwom.work_order_id
                            AND esib1.inventory_item_id = wwom.inventory_item_id
                            AND esib1.organization_id = wwom.organization_id
            --AND wdd.sales_order_number = wwob.work_order_number
                            AND wwom.wo_operation_id = wwopb.wo_operation_id
                            AND wwopb.organization_id = wwcb.organization_id
                            AND wwopb.work_center_id = wwcb.work_center_id
                            AND wwcb1.work_center_id IN (
                                SELECT
                                    work_center_id
                                FROM
                                    panduit_wie_wo_operations_b_tbl
                                WHERE
                                        operation_seq_number = wwopb.previous_cp_op_seq_num
                                    AND work_order_id = wwopb.work_order_id
                            )
                            AND wwcb1.organization_id IN (
                                SELECT
                                    organization_id
                                FROM
                                    panduit_wie_wo_operations_b_tbl
                                WHERE
                                        operation_seq_number = wwopb.previous_cp_op_seq_num
                                    AND work_order_id = wwopb.work_order_id
                            )
                            AND wwcb1.work_center_code != 'OUTSIDE'
            --AND wwom.SUPPLY_TYPE = '1'
--AND wdd.sales_order_number = 'LP-10000099'
                            AND iop.organization_code = flv2.lookup_code (+)
                            AND flv2.lookup_type (+) = 'PANDUIT_INV_SPK-I-404-SHIP_TOL'
                            AND flv2.language (+) = 'US'
                            AND flv2.enabled_flag (+) = 'Y'
                        UNION ALL
                        SELECT DISTINCT
                            sales_order_number,
                            wmssoseqnum,
                            iop.organization_code,
                            pbut.business_unit_name,
                            wwob.work_order_number,
                            pha.segment1,
                            wdd.source_line_type,
                            CAST((from_tz(CAST(wdd.creation_date AS TIMESTAMP),
                                          '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP) creation_date,
                            CAST((from_tz(CAST(wdd.date_requested AS TIMESTAMP),
                                          '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP) date_requested,
                            hp.party_name                                            party_name1,
                            psav.address1,
                            psav.address2,
                            psav.address3,
                            psav.address4,
                            psav.postal_code,
                            psav.city,
                            psav.state                                               state1,
                            psav.country,
                            psav.province,
                            wdd.mode_of_transport,
                            wdd.service_level,
                            hp1.party_name,
                                                                      --updated as part of CON0001205-50833
                            flv1.tag                                                 tag1,
                                                                       --rt.attribute1 tag1,
                            wdd.currency_code,
                            CAST((from_tz(CAST(wdd.date_scheduled AS TIMESTAMP),
                                          '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP) date_scheduled,
                            bt.wmssonum,
                            flv.description                                          description1,
                            bt.record_id,
                            wdd.requested_quantity,
                            pla.line_num,
                            wdd.delivery_detail_id,
                            esib1.primary_uom_code,
                            wwom.quantity_per_product,
                            wwom.basis_type,
                            wwom.supply_type,
                            'null'                                                   item_number,
                            esib1.item_number                                        compitemnum,
                            material_seq_number,
                            'null'                                                   outside_process_service_flag,
                            wdd.sales_order_line_number,
                            flv2.description
                        FROM
                            panduit_wie_work_orders_b_tbl                           wwob,
                            panduit_wie_wo_operations_b_tbl                         wwopb,
                            pdt_erp_datasync.panduit_egp_system_items_b_tbl         esib,
                            pdt_erp_datasync.panduit_egp_system_items_b_tbl         esib1,
                            pdt_erp_datasync.panduit_wsh_delivery_details_tbl       wdd,
                            panduit_po_headers_tbl                                  pha,
                            panduit_hz_parties_tbl                                  hp,
                            panduit_hz_party_sites_tbl                              hps,
                            panduit_poz_suppliers_tbl                               ps,
                            panduit_poz_supplier_address_v_tbl                      psav,
                            panduit_hz_parties_tbl                                  hp1,
                            panduit_po_lines_tbl                                    pla,
                            pdt_erp_datasync.panduit_wie_wo_operation_materials_tbl wwom,
                            panduit_wis_work_centers_b_tbl                          wwcb,
                            panduit_wis_work_centers_b_tbl                          wwcb1,
--pdt_erp_datasync.panduit_egp_system_items_b_tbl    esib,
                            pdt_erp_datasync.panduit_inv_org_parameters_tbl         iop,
                            pdt_erp_datasync.panduit_po_line_locations_tbl          ploc,
                            panduit_business_unit_tbl                               pbut,
                            panduit_om_so_to_wms_tbl                                bt,
                            panduit_fnd_lookup_values_tbl                           flv,
                            panduit_fnd_lookup_values_tbl                           flv1,
                            panduit_fnd_lookup_values_tbl                           flv2
            --panduit_rcv_shipment_lines_tbl                          rsl,
            --panduit_rcv_transactions_tbl                             rt
                        WHERE
                                1 = 1
                            AND bt.order_number = wdd.sales_order_number
                            AND bt.attribute1 = wdd.delivery_detail_id
                --AND bt.order_number = wwob.WORK_ORDER_NUMBER
                            AND wwob.work_order_id = wwopb.work_order_id
                            AND esib.inventory_item_id = wwopb.osp_item_id
                            AND esib.organization_id = wwopb.organization_id
                            AND wdd.sales_order_number = wwob.work_order_number
           -- AND wdd.sales_order_number = bt.order_number
             --AND wdd.source_line_number = bt.ORDER_LINE_NUMBER
                            AND esib.inventory_item_id = wdd.inventory_item_id
                            AND esib.organization_id = wdd.organization_id
                            AND wdd.sales_order_line_number = wwopb.operation_seq_number
                            AND wdd.source_header_number = pha.segment1
                            AND hp.party_id = hps.party_id
                            AND hp.party_id = ps.party_id
                            AND ps.vendor_id = pha.vendor_id
                            AND hps.party_id = psav.party_id
                            AND hps.party_site_id = psav.party_site_id
                            AND hps.location_id = psav.location_id
                            AND psav.last_update_date = (
                                SELECT
                                    MAX(last_update_date)
                                FROM
                                    panduit_poz_supplier_address_v_tbl
                                WHERE
                                    party_id = psav.party_id
                            )
                            AND wdd.carrier_id = hp1.party_id (+)
                            AND pha.po_header_id = pla.po_header_id
                            AND pla.item_id = esib.inventory_item_id
                            AND esib.organization_id = iop.organization_id
                            AND pla.po_line_id = ploc.po_line_id
                            AND ploc.ship_to_organization_id = iop.organization_id
                            AND pha.billto_bu_id = pbut.business_unit_id
                            AND wdd.source_line_type = 'OUTSIDE_PROCESSING'
                            AND iop.organization_code IN (
                                SELECT
                                    meaning
                                FROM
                                    panduit_fnd_lookup_values_tbl
                                WHERE
                                        lookup_type = 'PND_WMS_ORGLOC_OSP'
                                    AND language = 'US'
                            )
                            AND iop.organization_code = flv.lookup_code (+)
                            AND flv.lookup_type (+) = 'PANDUIT_INV_SPK-I-404_SHIPMETH'
                            AND flv.language (+) = 'US'
                             AND flv.enabled_flag (+) = 'Y'
                            AND pha.freight_terms_lookup_code = flv1.lookup_code (+)
                            AND flv1.lookup_type (+) = 'FREIGHT TERMS'
                            AND flv1.language (+) = 'US'
                            AND flv1.enabled_flag (+) = 'Y'
            /*AND rsl.po_header_id = pha.po_header_id
            AND rsl.po_line_id = pla.po_line_id
            AND wdd.sales_order_shipment_number=rt.transaction_id
            AND rsl.shipment_header_id = rt.shipment_header_id
            AND rsl.shipment_line_id = rt.shipment_line_id
            AND rt.attribute_category = 'Freightterm'
            AND rt.transaction_type='OUTSIDE_PROCESSING'*/
                            AND bt.status IN ( 'NEW', 'REPROCESS' )
                            AND bt.rice_id = 'SPK-I-404'
                            AND wwob.work_order_id = wwom.work_order_id
                            AND esib1.inventory_item_id = wwom.inventory_item_id
                            AND esib1.organization_id = wwom.organization_id
            --AND wdd.sales_order_number = wwob.work_order_number
                            AND wwom.wo_operation_id = wwopb.wo_operation_id
                            AND wwopb.organization_id = wwcb.organization_id
                            AND wwopb.work_center_id = wwcb.work_center_id
                            AND wwcb1.work_center_id IN (
                                SELECT
                                    work_center_id
                                FROM
                                    panduit_wie_wo_operations_b_tbl
                                WHERE
                                        operation_seq_number = wwopb.previous_cp_op_seq_num
                                    AND work_order_id = wwopb.work_order_id
                            )
                            AND wwcb1.organization_id IN (
                                SELECT
                                    organization_id
                                FROM
                                    panduit_wie_wo_operations_b_tbl
                                WHERE
                                        operation_seq_number = wwopb.previous_cp_op_seq_num
                                    AND work_order_id = wwopb.work_order_id
                            )
            --AND wwcb1.work_center_code != 'OUTSIDE'
                            AND wwom.supply_type = '1'
--AND wdd.sales_order_number = 'LP-10000099'

                            AND iop.organization_code = flv2.lookup_code (+)
                            AND flv2.lookup_type (+) = 'PANDUIT_INV_SPK-I-404-SHIP_TOL'
                            AND flv2.language (+) = 'US'
                            AND flv2.enabled_flag (+) = 'Y'
                    )
                GROUP BY
                    work_order_number,
            --esib.item_number,
                    segment1,
                    source_line_type,
                    creation_date,
                    date_requested,
                    party_name1,
                    address1,
                    address2,
                    address3,
                    address4,
                    postal_code,
                    city,
                    state1,
                    country,
                    province,
                    mode_of_transport,
                    service_level,
                    party_name,
                    tag1,
                    currency_code,
                    date_scheduled,
                    organization_code,
                    business_unit_name,
                    wmssonum,
                    description1,
                    sales_order_number,
             --iop.TIMEZONE_CODE,
                    wmssoseqnum
            );

    BEGIN
        BEGIN
            var_order_data := panduit_scm_fetch_source_order_for_wms_tab_typ();
            var_order_data_out := panduit_scm_fetch_source_order_for_wms_tab_typ();
            var_order_data.extend;
            OPEN c_process_records;
            LOOP
                FETCH c_process_records
                BULK COLLECT INTO var_order_data LIMIT gv_bulk_limit;
                EXIT WHEN var_order_data.count = 0;
                IF var_order_data.count > 0 THEN
                    FOR i IN var_order_data.first..var_order_data.last LOOP
                        var_order_data_out.extend;
                        var_order_data_out(var_order_data_out.last) := var_order_data(i);
                    END LOOP;
                END IF;

            END LOOP;

            CLOSE c_process_records;
            p_status := 'SUCCESS';
        EXCEPTION
            WHEN OTHERS THEN
                p_status := 'ERROR';
                p_error_message := 'Error in fetching Data from Base tables'
                                   || sqlerrm
                                   || ' '
                                   || dbms_utility.format_error_backtrace;
                ROLLBACK;
        END;

        BEGIN
            UPDATE panduit_om_so_to_wms_tbl
            SET
                status = 'PROCESSING',
                child_integration_instance_id_1 = p_instance_id,
                last_update_date = CAST(systimestamp AS TIMESTAMP(3))
            WHERE
                    1 = 1
                AND status IN ( 'NEW', 'REPROCESS' );

            p_status := 'SUCCESS';
        EXCEPTION
            WHEN OTHERS THEN
                p_status := 'ERROR';
                p_error_message := 'Error in Updating Data into PANDUIT_TRANSACTION_AUDIT'
                                   || sqlerrm
                                   || ' '
                                   || dbms_utility.format_error_backtrace;
                ROLLBACK;
        END;

        p_order_data := var_order_data_out;
    END panduit_get_rtv_osp_from_trx_aduit_prc;
/************************************************************************************************************
    ** Program Unit : PROCEDURE
    ** Name         : panduit_get_order_for_otm_prc
    ** Description  : Procedure to GET SO data for OTM SPK-I-458.
    ** Parameters   : p_parent_instance_id
                      p_instance_id
                      p_parent_integration_identifier
                      p_integration_identifier
                      p_batch_number
					  p_status
                      p_error_message
                      p_order_data
**************************************************************************************************************/

    PROCEDURE panduit_get_order_for_otm_prc (
        p_parent_instance_id            IN VARCHAR2,
        p_instance_id                   IN VARCHAR2,
        p_parent_integration_identifier IN VARCHAR2,
        p_integration_identifier        IN VARCHAR2,
		p_batch_number           		IN VARCHAR2,
        p_status                        OUT VARCHAR2,
        p_error_message                 OUT VARCHAR2,
        p_order_data                    OUT panduit_scm_fetch_source_order_for_otm_tab_typ
    ) AS
        var_order_data panduit_scm_fetch_source_order_for_otm_tab_typ;
    BEGIN
        BEGIN
            SELECT
                panduit_scm_fetch_source_order_for_otm_rec_typ(order_number, json1_object)
            BULK COLLECT
            INTO var_order_data
            FROM
                (
                    SELECT
                        dha.order_number,
                      JSON_OBJECT (
                        KEY 'OrderReleaseID' VALUE bt.wmssonum,
                        KEY 'OrderNumber' VALUE dha.order_number,
                        KEY 'FreightTerms' VALUE flv.LOOKUP_CODE,
                        KEY 'DocumentName' VALUE (
                        SELECT
                            JSON_ARRAYAGG(
                                JSON_OBJECT(
                                    KEY 'CategoryName' VALUE fadc.category_name,
                                    KEY 'FileName' VALUE REGEXP_REPLACE(fdtc.description, '[^a-zA-Z0-9[:space:]:.*-@%#,$&''()^{}/!_+|;<>?]', ' ')
                                RETURNING CLOB)
                            RETURNING CLOB)
                        FROM
                            pdt_erp_datasync.panduit_fnd_attached_documents_tbl fadc,
                            pdt_erp_datasync.panduit_fnd_documents_tl_tbl       fdtc,
                            pdt_erp_datasync.panduit_fnd_documents_tbl          fdc,
                            panduit_fnd_lookup_values_tbl fndc
                        WHERE
                                1 = 1
                            AND to_char(dha.header_id) = to_char(fadc.pk1_value)
                            AND fadc.document_id = fdtc.document_id 
                            AND fdtc.language = 'US'
                            AND fdtc.document_id = fdc.document_id
                            AND fdc.datatype_code  = 'TEXT'
                            AND fadc.category_name = fndc.meaning
                            AND fndc.lookup_type = 'PND_ATTACHMENT_CATEGORY'
                            AND fndc.language = 'US'
                    ),
                                                                                                                                                    key 'ModeOfShipment' VALUE wdd.mode_of_transport,
                        KEY 'Carrier' VALUE hp1.party_name,
                        KEY 'ServiceLevel' VALUE wdd.service_level,
                        KEY 'HoldForWarehouse' VALUE dfleb1.attribute_char17,
                        KEY 'OrderType' VALUE dha.order_type_code,
                        KEY 'PONumber' VALUE dha.customer_po_number,
                        KEY 'OrderSellingPrice' VALUE (ROUND(SUM(dla.extended_amount),2)),
                        KEY 'RSDMin' VALUE to_char(
                          MIN(
                            CAST(
                              (
                                from_tz(
                                  CAST(dfla.request_ship_date AS TIMESTAMP),
                                  '+00:00'
                                ) AT TIME ZONE (iop.timezone_code)
                              ) AS TIMESTAMP
                            )
                          ),
                          'YYYY-MM-DD"T"HH24:MI:SS'
                        ),
                        KEY 'SSDMin' VALUE to_char(
                          MIN(
                            CAST(
                              (
                                from_tz(
                                  CAST(dfla.schedule_ship_date AS TIMESTAMP),
                                  '+00:00'
                                ) AT TIME ZONE (iop.timezone_code)
                              ) AS TIMESTAMP
                            )
                          ),
                          'YYYY-MM-DD"T"HH24:MI:SS'
                        ),
                        KEY 'HrdRSD' VALUE to_char(
                          CAST(
                            (
                              from_tz(
                                CAST(dha.request_ship_date AS TIMESTAMP),
                                '+00:00'
                              ) AT TIME ZONE (iop.timezone_code)
                            ) AS TIMESTAMP
                          ),
                          'YYYY-MM-DD"T"HH24:MI:SS'
                        ),
                        KEY 'ShipFromLocation' VALUE concat('WH_', iop.organization_code),
                        KEY 'ShipToLocation' VALUE concat('CS_', doa.party_site_id),
                        KEY 'TransactionalCurrencyCode' VALUE dha.transactional_currency_code,
                        KEY 'ShipToCustName' VALUE TRIM(substr(hps6.party_site_name, 1, 50)), --Added on 16/5/2025 for CON0001205-95558
                        /**********************************************
                        ** Added as part of CON0001205-96284
                        ***********************************************/
                        KEY 'ShipToAddress1' VALUE TRIM(substr(nvl(h2.address1, h4.address1), 1, 70)),
                        KEY 'ShipToAddress2' VALUE TRIM(substr(nvl(h2.address2, h4.address2), 1, 100)),
                        KEY 'ShipToAddress3' VALUE nvl(h2.address3, h4.address3),
                        --KEY 'ShipToAddress4' VALUE nvl(h2.address4, h4.address4),
                        KEY 'ShipToPstlcde' VALUE nvl(h2.postal_code, h4.postal_code),
                        KEY 'ShipToCity' VALUE nvl(h2.city, h4.city),
                        KEY 'ShipToState' VALUE(
                          CASE
                            WHEN h2.country = 'CA'
                            OR h4.country = 'CA' THEN nvl(h2.province, h4.province)
                            ELSE nvl(h2.state, h4.state)
                          END
                        ),
                        KEY 'ShipToCountry' VALUE nvl(h2.country, h4.country),
                        KEY 'Email' VALUE hcp.email_address,
                        KEY 'PhoneNumber' VALUE hcp1.phone_number,
                        /***********************************************/
                        /**********************************************
                        ** Added as part of CON0001205-96284
                        ***********************************************/
                        KEY 'ParcelShipMethod' VALUE hcasd1.attribute8,
                        KEY 'LTLShipMethod' VALUE hcasd1.attribute9,
                        KEY 'SourceCountry' VALUE hl.country,
                        KEY 'DestinationCountry' VALUE(
                          CASE
                            WHEN dheb.attribute_char9 IS NOT NULL THEN hzcsua1.country
                            ELSE hzcsua2.country
                          END
                        ),
                        /***********************************************/
                        KEY 'lines' VALUE JSON_ARRAYAGG (
                          JSON_OBJECT (
                            KEY 'FulfilLineId' VALUE dfla.fulfill_line_id,
                            KEY 'LineId' VALUE dla.line_id,
                            KEY 'DeliveryDetailId' VALUE wdd.delivery_detail_id,
                            KEY 'ItemId' VALUE esib.inventory_item_id,
                            KEY 'ItemNumber' VALUE esib.item_number,
                            KEY 'ItemWeight' VALUE (ROUND(esib.unit_weight,2)),
                            KEY 'ItemWeightUOM' VALUE esib.weight_uom_code,
                            KEY 'ItemVolume' VALUE (ROUND(esib.unit_volume,2)),
                            KEY 'ItemVolumeUOM' VALUE esib.volume_uom_code,
                            KEY 'OrderedQuantity' VALUE wdd.requested_quantity,
                            KEY 'UnitSellingPrice' VALUE (ROUND(dla.unit_selling_price,2)),
                            KEY 'RSD' VALUE to_char(
                              CAST(
                                (
                                  from_tz(
                                    CAST(dfla.request_ship_date AS TIMESTAMP),
                                    '+00:00'
                                  ) AT TIME ZONE (iop.timezone_code)
                                ) AS TIMESTAMP
                              ),
                              'YYYY-MM-DD"T"HH24:MI:SS'
                            ),
                            KEY 'SSD' VALUE to_char(
                              CAST(
                                (
                                  from_tz(
                                    CAST(dfla.schedule_ship_date AS TIMESTAMP),
                                    '+00:00'
                                  ) AT TIME ZONE (iop.timezone_code)
                                ) AS TIMESTAMP
                              ),
                              'YYYY-MM-DD"T"HH24:MI:SS'
                            ),
                            KEY 'SiteUseId' VALUE(
                              CASE
                                WHEN dheb.attribute_number1 IS NOT NULL THEN concat('CS_', hcas4.party_site_id)
                                ELSE concat('CS_', dfla.ship_to_party_site_id)
                              END
                            ),
                            --KEY 'SiteUseId' VALUE concat('CS_',NVL(dheb.attribute_number1,dfla.ship_to_party_site_id)),
                            --KEY 'SiteUseId' VALUE dheb.attribute_number1,
                            KEY 'ShipToPartySiteID' VALUE concat('CS_', dfla.ship_to_party_site_id),
                            KEY 'OrgId' VALUE concat('WH_', dla.org_id),
                            KEY 'BillToPartySiteId' VALUE concat('CS_', hcas.party_site_id),
                            KEY 'LegalEntityCode' VALUE bt.business_unit_name,
                            KEY 'FulfilLineNumber' VALUE dfla.fulfill_line_number,
                        -- KEY 'OrderedPrice' VALUE(ROUND((dla.unit_list_price * wdd.requested_quantity),2)),
                            KEY 'OrderedPrice' VALUE(ROUND((dla.unit_list_price * wdd.requested_quantity),2)),
                            KEY 'ItemLength' VALUE (ROUND(esib.unit_length,2)),
                            KEY 'ItemLengthUOM' VALUE esib.dimension_uom_code,
                            KEY 'ItemWidth' VALUE (ROUND(esib.unit_width,2)),
                            KEY 'ItemWidthUOM' VALUE esib.dimension_uom_code,
                            KEY 'ItemHeight' VALUE (ROUND(esib.unit_height,2)),
                            KEY 'ItemHeightUOM' VALUE esib.dimension_uom_code,
                            KEY 'ShippingInstructions' VALUE dfla.shipping_instructions,
                            KEY 'LineNumber' VALUE dla.display_line_number,
                            KEY 'ReleaseLineWeight' VALUE (ROUND((NVL(esib.unit_weight, 0) * wdd.requested_quantity), 2)),
                            KEY 'ReleaseLineVolume' VALUE (ROUND((NVL(esib.unit_volume, 0) * wdd.requested_quantity), 2))
                            RETURNING
                              CLOB
                          )
                          RETURNING
                            CLOB
                        )
                        RETURNING
                          CLOB
                      ) json1_object
                    FROM
                        panduit_om_so_to_wms_tbl                              bt,
                        panduit_doo_headers_all_tbl                           dha,
                        panduit_doo_fulfill_lines_all_tbl                     dfla,
                        panduit_doo_lines_all_tbl                             dla,
                        panduit_doo_order_addresses_tbl                       doa,
                        pdt_erp_datasync.panduit_msc_sr_lookup_values_vl_tbl  msl,
                        pdt_erp_datasync.panduit_fnd_lookup_values_tbl        flv,
                        panduit_hz_parties_tbl                                hp,
                        panduit_hz_parties_tbl                                hp1,
                        pdt_erp_datasync.panduit_wsh_delivery_details_tbl     wdd,
                        pdt_erp_datasync.panduit_doo_fulfill_lines_eff_b_tbl  dfleb1,
                        panduit_business_unit_tbl                             pbut,
                        pdt_erp_datasync.panduit_inv_org_parameters_tbl       iop,
                        pdt_erp_datasync.panduit_egp_system_items_b_tbl       esib,
                        panduit_doo_headers_eff_b_tbl                         dheb,
                        panduit_hz_cust_acct_sites_tbl                        hcas3,
                        panduit_hz_cust_acct_sites_tbl                        hcas4,
                        pdt_erp_datasync.panduit_hz_party_sites_tbl           hps6, --Added on 16/5/2025 for CON0001205-95558
                        panduit_doo_order_addresses_tbl                       doa1,
                        panduit_hz_cust_accounts_tbl                          hca,
                        pdt_erp_datasync.panduit_hz_cust_acct_sites_tbl       hzcsua,
                        panduit_hz_cust_acct_sites_tbl                        hcas,
                        panduit_hz_party_sites_tbl                            hps1,
                        panduit_hz_locations_tbl                              h2,
                        panduit_hz_locations_tbl                              h4,
                        pdt_erp_datasync.panduit_hz_contact_points_tbl        hcp,
                        pdt_erp_datasync.panduit_hz_contact_points_tbl        hcp1,
                        pdt_erp_datasync.panduit_hz_cust_acct_sites_tbl       hzcsua6,
                        pdt_erp_datasync.panduit_hz_locations_tbl             h5,
                        pdt_erp_datasync.panduit_hz_organization_profiles_tbl hop,
                        panduit_cust_acct_sites_dff_tbl                       hcasd3,
                        panduit_hz_party_sites_tbl                            hps,
                        pdt_erp_datasync.panduit_zx_registrations_tbl         zr,
                        pdt_erp_datasync.panduit_zx_party_tax_profile_tbl     zptp,
                        panduit_cust_acct_sites_dff_tbl                       hcasd,
                        panduit_doo_headers_eff_b_tbl                         dheb1,
                        pdt_erp_datasync.panduit_wsh_carriers_tbl             wc,
                        pdt_erp_datasync.panduit_wsh_carriers_tbl             wc_default,
                        /*
						pdt_erp_datasync.panduit_fnd_attached_documents_tbl   fad,
                        pdt_erp_datasync.panduit_fnd_documents_tl_tbl         fdt,
                        pdt_erp_datasync.panduit_fnd_documents_tbl            fd,
                        pdt_erp_datasync.panduit_fnd_attached_documents_tbl   fad1,
                        pdt_erp_datasync.panduit_fnd_documents_tl_tbl         fdt1,
                        pdt_erp_datasync.panduit_fnd_documents_tbl            fd1,
                        pdt_erp_datasync.panduit_fnd_attached_documents_tbl   fad2,
                        pdt_erp_datasync.panduit_fnd_documents_tl_tbl         fdt2,
                        pdt_erp_datasync.panduit_fnd_documents_tbl            fd2,
						*/
                        panduit_fnd_lookup_values_tbl                         flv2,
                        panduit_fnd_lookup_values_tbl                         flv3,
                        panduit_cust_acct_sites_dff_tbl                       hcasd2,
                        panduit_hz_parties_tbl                                hp2,
                        panduit_hz_party_sites_tbl                            hps2,
                        panduit_cust_acct_sites_dff_tbl                       hcasd1,
                        panduit_hr_locations_tbl                              hl,
                        pdt_erp_datasync.panduit_hz_cust_acct_sites_tbl       hzcsua1,
                        pdt_erp_datasync.panduit_hz_cust_acct_sites_tbl       hzcsua2
                    WHERE
                            1 = 1
                        AND bt.status = 'SUCCESS'
                        AND bt.otm_status IN ('NEW', 'REPROCESS')
						AND bt.batch_number = p_batch_number
                        AND bt.order_number = dha.order_number
                        AND bt.attribute1 = dfla.fulfill_line_id
                        AND bt.order_line_number = dla.display_line_number
                        AND bt.delivery_detail_id = wdd.delivery_detail_id
                        AND dha.header_id = dfla.header_id
                        AND dha.header_id = dla.header_id
                        AND dfla.line_id = dla.line_id
                        AND dfla.fulfill_org_id = iop.organization_id
                        AND iop.organization_code IN (
                            SELECT
                                meaning
                            FROM
                                panduit_fnd_lookup_values_tbl
                            WHERE
                                    lookup_type = 'PANDUIT_ORGS_OTM'
                                AND language = 'US'
                        )
                        AND pbut.business_unit_id = dha.org_id
                        AND bt.business_unit_name = pbut.business_unit_name
						---------------------------------------------
							--ShipTO
						---------------------------------------------
                        AND dha.header_id = doa.header_id (+)
                        AND doa.address_use_type (+) = 'SHIP_TO'
						/***Added for CON0001205-96284***/
                        AND doa.party_site_id = hps1.party_site_id (+)
                        AND hps1.status (+) = 'A'
                        AND hps1.location_id = h2.location_id (+)
                        AND h2.status_flag (+) = 'A'
						-----
                        AND dfla.ship_to_party_site_id = hcas3.account_site_party_site_id (+)
                        AND hcas3.location_id = h4.location_id (+)
                         AND h4.status_flag (+) = 'A'
                        AND hcas3.site_use_code (+) = 'SHIP_TO'
                        AND hcas3.status (+) = 'A'
                        AND dha.sold_to_party_contact_id = hcp.relationship_id (+)
                        AND hcp.contact_point_type (+) = 'EMAIL'
                        AND hcp.primary_flag (+) = 'Y'
                        AND hcp.status (+) = 'A' --CON0001205-116065
                        AND dha.sold_to_party_contact_id = hcp1.relationship_id (+)
                        AND hcp1.contact_point_type (+) = 'PHONE'
                        AND hcp1.primary_flag (+) = 'Y'
                        AND hcp1.status (+) = 'A' --CON0001205-116065
						---------------------------------------------
							--Freight terms
						---------------------------------------------
                        AND dfla.freight_terms_code = msl.lookup_code (+)
                        AND flv.lookup_type (+) = 'WSH_FREIGHT_CHARGE_TERMS'
                        AND msl.meaning = flv.meaning (+)
                        AND msl.lookup_type (+) = 'WSH_FREIGHT_CHARGE_TERMS'
                        AND flv.language (+) = 'US'
                         AND flv.enabled_flag (+) = 'Y'
						---------------------------------------------
						--Order Attachment
						---------------------------------------------
						/*
						AND to_char(dha.header_id) = to_char(fad.pk1_value(+))
						AND fad.document_id = fdt.document_id(+)
						AND fdt.language(+) = 'US'
						AND fdt.document_id = fd.document_id(+)
						AND fd.datatype_code(+) = 'TEXT'
						*/
						---------------------------------------------
							--Shipping Method
						---------------------------------------------
						/* 
						AND ( dfla.fulfill_line_id = wdd.source_shipment_id
								OR dfla.split_from_fline_id = wdd.source_shipment_id )
						*/
                        AND nvl(dfla.fulfillment_split_ref_id, dfla.fulfill_line_id) = wdd.source_shipment_id
                        AND wdd.carrier_id = hp1.party_id (+)
                        AND hp1.status (+) = 'A'
						---------------------------------------------
							--Warehouse DFF
						---------------------------------------------
                        AND dfla.fulfill_line_id = dfleb1.fulfill_line_id (+)
                        AND dfleb1.context_code (+) = 'Common'
						---------------------------------------------
							--Item
						---------------------------------------------
                        AND esib.inventory_item_id = wdd.inventory_item_id
                        AND esib.organization_id = iop.master_organization_id
						---------------------------------------------
							--Invole Party
						---------------------------------------------
                        AND dha.header_id = dheb.header_id (+)
                        AND dheb.context_code (+) = 'Common'
                        AND hcas4.site_use_id (+) = dheb.attribute_number1
                        AND hcas4.site_use_code (+) = 'SOLD_TO'
                        AND hcas4.status (+) = 'A'
						---------------------------------------------
							--Hard Coded Freight Instructions 
							--Added for CON0001205-93918
						---------------------------------------------
                        AND doa.party_site_id = hcasd1.party_site_id (+)
                        AND dfla.fulfill_org_id = hl.inventory_organization_id (+)
                        AND hl.active_status (+) = 'A'
                        AND dheb.attribute_char9 = hzcsua1.party_site_number (+)
                        AND hzcsua1.status (+) = 'A'
                        AND hzcsua1.site_use_code (+) = 'SHIP_TO'

                        AND doa.party_site_id = hzcsua2.party_site_id (+)
                        AND hzcsua2.site_use_code (+) = 'SHIP_TO'
                        AND hzcsua2.status (+) = 'A'
						---------------------------------------------
							--Invole Party - Bill To
						---------------------------------------------
                        AND dha.header_id = doa1.header_id (+)
                        AND doa1.address_use_type (+) = 'BILL_TO'                     
                        AND doa1.cust_acct_id = hca.cust_account_id (+)
                        AND hca.status (+) = 'A'
                        AND doa1.cust_acct_site_use_id = hzcsua.site_use_id (+)
                        AND hzcsua.cust_account_site_id = hcas.cust_account_site_id (+)
                        AND hcas.site_use_code (+) = 'BILL_TO'
                        AND hcas.status (+) = 'A'
                        AND hzcsua.status (+) = 'A'
						---------------------------------------------
							--Legal Entity
						---------------------------------------------
                        AND wdd.ship_to_party_site_id = hps6.party_site_id (+) --Added on 16/5/2025 for CON0001205-95558
						AND hps6.status (+) = 'A'
                        /******For same grouping logic as 078***********/
                        AND dheb.attribute_number1 = hzcsua6.site_use_id (+)
                        AND hzcsua6.status (+) = 'A'
                        AND hzcsua6.location_id = h5.location_id (+)
                        AND h5.status_flag (+) = 'A'
                        AND dha.sold_to_party_id = hp.party_id
                        AND hp.status = 'A'
                        AND hp.party_id = hop.party_id (+)
                        AND hcasd3.cust_acct_site_id (+) = hcas4.cust_account_site_id
                        AND hp.party_id = hps.party_id (+)
                        AND hps.status (+) = 'A'
                        AND hps.party_site_id = hcasd.party_site_id (+)
                        AND hps.party_site_id = zptp.party_id (+)
                        AND zptp.party_tax_profile_id = zr.party_tax_profile_id (+)
                        AND hcas.party_site_id = hps.party_site_id (+)
                        AND dha.header_id = dheb1.header_id (+)
                        AND dheb1.context_code (+) = 'EDI3'
                        AND wdd.carrier_id = wc.carrier_id (+)
                        AND wc_default.carrier_name (+) = 'FED'
						--
                        /*
						AND dha.header_id = fad.pk1_value (+)
                        AND fad.document_id = fdt.document_id (+)
                        AND fdt.language (+) = 'US'
                        AND fdt.document_id = fd.document_id (+)
                        AND fd.datatype_code (+) = 'TEXT'
                        AND fad.category_name (+) = 'PACKING SLIP'
                        AND dha.header_id = fad1.pk1_value (+)
                        AND fad1.document_id = fdt1.document_id (+)
                        AND fdt1.language (+) = 'US'
                        AND fdt1.document_id = fd1.document_id (+)
                        AND fd1.datatype_code (+) = 'TEXT'
                        AND fad1.category_name (+) = 'WAREHOUSE MESSAGE'
                        AND dha.header_id = fad2.pk1_value (+)
                        AND fad2.document_id = fdt2.document_id (+)
                        AND fdt2.language (+) = 'US'
                        AND fdt2.document_id = fd2.document_id (+)
                        AND fd2.datatype_code (+) = 'TEXT'
                        AND fad2.category_name (+) = 'BILL OF LADING MESSAGE'
						*/
						--
                        AND dfla.ship_to_party_site_id = hcasd2.party_site_id (+)
                        AND hcasd2.acct_site_language = flv2.lookup_code (+)
                        AND flv2.lookup_type (+) = 'PER_CORRESP_LANG'
                        AND flv2.language (+) = 'US'
                        AND flv2.enabled_flag (+) = 'Y'
						--
                        AND hp1.party_name = substr(flv3.meaning(+), 1, instr(flv3.meaning(+), '-') - 1)
                        AND flv3.lookup_type (+) = 'PANDUIT_OM_DUMMY_SHIPPING_METH'
                        AND flv3.language (+) = 'US'
                        AND flv3.enabled_flag (+) = 'Y' -- Added by Abdul
						--
                        AND h4.location_id = hps2.location_id (+)
                        AND hps2.party_id = hp2.party_id (+)
                        AND hp2.status (+) = 'A'
                    GROUP BY
                        bt.wmssonum,
                        bt.wmssoseqnum,
                        dha.header_id,
                        iop.organization_code,
                        pbut.business_unit_name,
                        dha.source_order_system,
                        dha.order_number,
                        dha.order_type_code,
                        dha.customer_po_number,
                        to_char(CAST((from_tz(CAST(dha.ordered_date AS TIMESTAMP), '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP), 'YYYY/MM/DD HH24:MI:SS'),
						/***Added for CON0001205-96284***/
                        h2.address1,
                        h2.address2,
                        h2.address3,
                        h2.address4,
                        h2.postal_code,
                        h2.city,
                        h2.state,
                        h2.country,
                        h2.province,
                        h4.address1,
                        h4.address2,
                        h4.address3,
                        h4.address4,
                        h4.postal_code,
                        h4.city,
                        h4.state,
                        h4.country,
                        h4.province,
                        hcp.email_address,
                        hcp1.phone_number,
						/*******************************/
						---------------------------------------	
                        msl.meaning,
                        flv.lookup_code,
                        dfleb1.attribute_char17,
                        dha.request_ship_date,
                        doa.party_site_id,
                        hps6.party_site_name, --Added on 16/5/2025 for CON0001205-95558
						/******For same grouping logic as 078***********/
                        dha.transactional_currency_code,
                        dha.earliest_acceptable_ship_date,
                        dha.latest_acceptable_ship_date,
                        dha.packing_instructions,
                        dha.shipment_priority_code,
                        wdd.mode_of_transport,
                        hp1.party_name,
                        wdd.service_level,
                        dha.sales_channel_code,
                        to_char(CAST((from_tz(CAST(dha.request_ship_date AS TIMESTAMP), '+00:00') AT TIME ZONE(iop.timezone_code)) AS TIMESTAMP), 'YYYY-MM-DD"T"HH24:MI:SS'),
                        wdd.freight_terms_code,
						---
                        h5.address1,
                        h5.address2,
                        h5.address3,
                        h5.address4,
                        h5.postal_code,
                        h5.city,
                        h5.state,
                        h5.country,
                        h5.province,
						---
                        hp.party_number,
                        hop.attribute2,
                        dheb.attribute_char4,
                        dheb.attribute_char10,
                        dheb.attribute_char1,
                        dheb.attribute_char9,
                        hcasd3.attribute14,
                        hcasd3.ece_tp_location_code,
                        hcasd3.attribute16,
                        zr.registration_number,
                        dheb1.attribute_char2,
                        wc.attribute1,
                        wc.attribute2,
                        wc_default.attribute1,
                        wc_default.attribute2,
                        /*
						fdt.description,
                        fad.category_name,
                        fdt1.description,
                        fdt2.description,
						*/
                        flv2.meaning,
                        flv3.meaning,
                        hp2.party_name,
                        hcasd2.ece_tp_location_code,
                        hp2.party_number,
                        hzcsua6.party_site_name,
						/*******************************/
                        hcasd1.attribute8,
                        hcasd1.attribute9,
                        hl.country,
                        hzcsua1.country,
                        hzcsua2.country
                );

            p_status := 'SUCCESS';
        EXCEPTION
            WHEN OTHERS THEN
                p_status := 'ERROR';
                p_error_message := 'Error in fetching Data from Base tables'
                                   || sqlerrm
                                   || ' '
                                   || dbms_utility.format_error_backtrace;
                ROLLBACK;
        END;

        BEGIN
            UPDATE panduit_om_so_to_wms_tbl
            SET
                otm_status = 'PROCESSING',
                otm_integration_instance_id = p_instance_id,
                last_update_date = CAST(systimestamp AS TIMESTAMP(3))
            WHERE
                    1 = 1
                AND status = 'SUCCESS'
                AND otm_status IN ( 'NEW', 'REPROCESS' )
                AND batch_number = p_batch_number;

            p_status := 'SUCCESS';
        EXCEPTION
            WHEN OTHERS THEN
                p_status := 'ERROR';
                p_error_message := 'Error in Updating Data into PANDUIT_OM_SO_TO_WMS_TBL'
                                   || sqlerrm
                                   || ' '
                                   || dbms_utility.format_error_backtrace;
                ROLLBACK;
        END;

        p_order_data := var_order_data;
    END panduit_get_order_for_otm_prc;

/************************************************************************************************************
		** Program Unit : PROCEDURE
		** Name         : panduit_batch_so_for_wms_prc
		** Description  : Procedure to update and get batch number for SPK-I-078.
		** Parameters   : p_instance_id
						  p_rice_id
                          p_rec_per_batch
                          p_max_batch_no
						  p_status
						  p_error_message
**************************************************************************************************************/
    PROCEDURE panduit_batch_so_for_wms_prc (
        p_instance_id   IN VARCHAR2,
        p_rice_id       IN VARCHAR2,
        p_rec_per_batch IN VARCHAR2,
        p_max_batch_no  OUT NUMBER,
        p_status        OUT VARCHAR2,
        p_error_message OUT VARCHAR2
    ) AS

        l_total_rec_cnt    NUMBER := 0;
        l_batch_rec_cnt    NUMBER := 0;
        l_batch_num        NUMBER := 1;
        l_batch_size       NUMBER := 0;
        l_update_statement CLOB;
        l_total_batch      NUMBER;
        l_count            NUMBER := 0;
        l_otm_rp_count     NUMBER := 0;

        --Cursor to determine the batch numbers for each order
        CURSOR batch_cur IS
        WITH main_query AS (
            SELECT
                order_number
            FROM
                panduit_om_so_to_wms_tbl
            WHERE
                status IN ( 'NEW', 'REPROCESS' )
                AND rice_id = p_rice_id
        ), order_line_counts AS (
            SELECT
                order_number,
                COUNT(*) AS line_count
            FROM
                main_query
            GROUP BY
                order_number
        ), ordered_orders AS (
            SELECT
                order_number,
                line_count,
                SUM(line_count)
                OVER(
                ORDER BY
                    order_number
                ) AS running_total
            FROM
                order_line_counts
            ORDER BY
                order_number
        ), batched_orders AS (
            SELECT
                order_number,
                line_count,
                floor((running_total - 1) / p_rec_per_batch) + 1 AS batch_id
            FROM
                ordered_orders
            ORDER BY
                order_number
        )
        SELECT
            order_number,
            batch_id,
            MAX(batch_id)
            OVER() max_batch
        FROM
            batched_orders;

        TYPE l_batch_data_t IS
            TABLE OF batch_cur%rowtype;
        l_batch_data     l_batch_data_t;
    BEGIN
        --Update the table with batch number
        OPEN batch_cur;
        LOOP
            FETCH batch_cur
            BULK COLLECT INTO l_batch_data LIMIT 10000;
            EXIT WHEN l_batch_data.count = 0;
            l_total_batch := nvl(l_batch_data(l_batch_data.first).max_batch, 0);
            FORALL i IN l_batch_data.first..l_batch_data.last
                UPDATE panduit_om_so_to_wms_tbl
                SET
                    batch_number = p_instance_id
                                   || '_'
                                   || l_batch_data(i).batch_id
                WHERE
                    status IN ( 'NEW', 'REPROCESS' )
                    AND order_number = l_batch_data(i).order_number;

        END LOOP;

        CLOSE batch_cur;
        COMMIT;
        p_max_batch_no := l_total_batch;
        p_status := 'SUCCESS';
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_error_message := 'Error in Batching logic '
                               || sqlerrm
                               || ' '
                               || dbms_utility.format_error_backtrace;
            ROLLBACK;
            BEGIN
                UPDATE panduit_om_so_to_wms_tbl
                SET
                    status = 'ERROR',
                    error_message = p_error_message
                WHERE
                    oic_instance_id = p_instance_id;

                COMMIT;
            END;

    END;
/************************************************************************************************************
		** Program Unit : PROCEDURE
		** Name         : panduit_so_special_char_valid_prc
		** Description  : Procedure to check the special chracter validation for SPK-I-078.
		** Parameters   : p_instance_id
						  p_rice_id
						  p_status
						  p_error_message
**************************************************************************************************************/
     PROCEDURE panduit_so_special_char_valid_prc (
        p_instance_id   IN VARCHAR2,
        p_rice_id       IN VARCHAR2,
        p_status        OUT VARCHAR2,
        p_error_message OUT VARCHAR2
    ) AS

        l_count          NUMBER := 0;
        v_response       CLOB;
        v_payload        CLOB;
        l_paas_user_name VARCHAR2(100);
        l_paas_password  VARCHAR2(100);
        l_paas_url       VARCHAR2(1000);
        l_order_list     VARCHAR2(4000);
        --Cursor to Check for special Character
        CURSOR sp_char_cur IS
        WITH attachments AS (
            SELECT
                fdt.description,
                dha.order_number
            FROM
                panduit_doo_headers_all_tbl                         dha,
                pdt_erp_datasync.panduit_fnd_attached_documents_tbl fad,
                pdt_erp_datasync.panduit_fnd_documents_tl_tbl       fdt,
                pdt_erp_datasync.panduit_fnd_documents_tbl          fd,
                panduit_fnd_lookup_values_tbl                       fndc
            WHERE
                    1 = 1
                AND to_char(dha.header_id) = to_char(fad.pk1_value)
                AND fad.document_id = fdt.document_id
                AND fdt.language = 'US'
                AND fdt.document_id = fd.document_id
                AND fd.datatype_code = 'TEXT'
                AND fad.category_name = fndc.meaning
                AND fndc.lookup_type = 'PND_ATTACHMENT_CATEGORY'
                AND fndc.language = 'US'
                AND REGEXP_LIKE ( fdt.description,
                                  '[<>''"&]' )
        ), check_items AS (
            SELECT
                esib.item_number,
                esib.inventory_item_id,
                esib.organization_id
            FROM
                pdt_erp_datasync.panduit_egp_system_items_b_tbl esib
            WHERE
                    1 = 1
                AND REGEXP_LIKE ( esib.item_number,
                                  '[<>''"&]' )
        )
        SELECT
            main.order_number,
            main.attribute5,
            main.order_line_number,
            main.attribute1,
            main.delivery_detail_id
        FROM
            panduit_om_so_to_wms_tbl                           main,
            pdt_erp_datasync.panduit_doo_headers_all_tbl       dha,
            pdt_erp_datasync.panduit_doo_lines_all_tbl         dla,
            pdt_erp_datasync.panduit_doo_fulfill_lines_all_tbl dfla,
            pdt_erp_datasync.panduit_wsh_delivery_details_tbl  wdd,
            pdt_erp_datasync.panduit_inv_org_parameters_tbl    iop
        WHERE
                1 = 1
            AND main.oic_instance_id = p_instance_id
            AND status IN ( 'NEW', 'REPROCESS' )
            AND rice_id = p_rice_id
            AND dha.header_id = dla.header_id
            AND dha.header_id = dfla.header_id
            AND dfla.line_id = dla.line_id
            AND wdd.sales_order_number = dha.order_number
            AND wdd.source_line_number = dla.line_number
            AND nvl(dfla.fulfillment_split_ref_id, dfla.fulfill_line_id) = wdd.source_shipment_id
            AND dha.submitted_flag = 'Y'
            AND dfla.fulfill_org_id = iop.organization_id
            AND iop.organization_code = main.attribute5
            AND dha.order_number = main.order_number
            AND dla.display_line_number = main.order_line_number
            AND dfla.fulfill_line_id = main.attribute1
            AND wdd.delivery_detail_id = main.delivery_detail_id
            AND ( ( REGEXP_LIKE ( dfla.shipping_instructions,
                                  '[<>''"&]' ) )
                  OR ( REGEXP_LIKE ( dha.customer_po_number,
                                     '[<>''"&]' ) )
                  OR ( (
                SELECT
                    COUNT(*)
                FROM
                    attachments a
                WHERE
                        1 = 1
                    AND a.order_number = dha.order_number
            ) > 0 )
                  OR ( (
                SELECT
                    COUNT(*)
                FROM
                    check_items ct
                WHERE
                        1 = 1
                    AND ct.inventory_item_id = wdd.inventory_item_id
                    AND ct.organization_id = iop.organization_id
            ) > 0 ) );

        TYPE l_spc_data_t IS
            TABLE OF sp_char_cur%rowtype;
        l_spc_data       l_spc_data_t;
    BEGIN
        -- Iterate the cursor to update the orders status idetify with special character
        OPEN sp_char_cur;
        LOOP
            FETCH sp_char_cur
            BULK COLLECT INTO l_spc_data LIMIT 10000;
            EXIT WHEN l_spc_data.count = 0;
            FORALL i IN l_spc_data.first..l_spc_data.last
                UPDATE panduit_om_so_to_wms_tbl
                SET
                    status = 'ERROR',
                    error_message = 'Special Character Validation failed.',
                    otm_status = 'NA'
                WHERE
                        1 = 1
                    AND oic_instance_id = p_instance_id
                    AND status IN ( 'NEW', 'REPROCESS' )
                    AND order_number = l_spc_data(i).order_number
                    AND attribute5 = l_spc_data(i).attribute5
                    AND order_number = l_spc_data(i).order_number
                    AND order_line_number = l_spc_data(i).order_line_number
                    AND attribute1 = l_spc_data(i).attribute1
                    AND delivery_detail_id = l_spc_data(i).delivery_detail_id;

            l_count := SQL%rowcount;
        END LOOP;

        CLOSE sp_char_cur;

        -- Trigger the incident integration
        IF l_count > 0 THEN
            SELECT
                username,
                panduit_encryption_util_pkg.panduit_decrypt_data_prc(password_value) password
            INTO
                l_paas_user_name,
                l_paas_password
            FROM
                panduit_auth_params_tbl
            WHERE
                connection_type = 'PANDUIT_OIC_CREDENTIALS';

            SELECT
                lookup_code
            INTO l_paas_url
            FROM
                panduit_common_lookup_values_tbl
            WHERE
                lookup_type = 'PANDUIT_PAAS_URL';

            ---Call OIC Service now integration for error------
            apex_web_service.g_request_headers.DELETE();
            apex_web_service.g_request_cookies.DELETE();
            apex_web_service.g_request_headers(1).name := 'Content-Type';
            apex_web_service.g_request_headers(1).value := 'application/json';
        --
            v_payload := '{
  "InterfaceRiceId" : "SPK-I-078",
  "IntegrationName" : "PANDUIT SCM Oracle to OTM SO Child Integration",
  "IntegrationIdentifier" : "PAND_SCM_ORAC_TO_OTM_SO_CHIL_INT",
  "IntegrationVersion" : "01.00.0000",
  "instanceid" : "'
                         || p_instance_id
                         || '",
  "source" : "ATP",
  "module" : "OM",
  "category" : "",
  "subcategory" : "",
  "incidentSourceCall" : "Auto Ticket",
  "incidenttype" : "Preventative",
  "AssignTo" : "IT",
  "assigngroup" : "",
  "severityCode" : "1",
  "severityLevel" : "2",
  "createdBy" : "oic.admin",
  "lastUpdateBy" : "oic.admin",
   "errorDetails" : [ {
    "errorType" : "'
                         || 'Special character validation error'
                         || '",
    "errorCode" : "'
                         || 'Special character validation error'
                         || '",
    "errorSummary" : " Special character validation errors occurred in SPK-I-078. Please verify the boundary table PANDUIT_OM_SO_TO_WMS_TBL for the instance ID '
                         || p_instance_id
                         || ' and correct the fields."
  } ]
}
';
            --Invoke Web Service Call
            v_response := apex_web_service.make_rest_request(p_url =>(l_paas_url
                                                                      || '/ic/api/integration/v1/flows/rest/PANDUIT_SERVICENOW_INCIDENT_INT/1.0/incident'),
                                                                      p_http_method => 'POST', p_body => v_payload, p_username => l_paas_user_name,
                                                                      p_password => l_paas_password,
                                                            p_transfer_timeout => 300);

            UPDATE panduit_om_so_to_wms_tbl
            SET
                error_message = error_message
                                || CHR(10)
                                || 'Incident created. Status code: '
                                || apex_web_service.g_status_code
                                || '. Reason: '
                                || apex_web_service.g_reason_phrase
            WHERE
                    oic_instance_id = p_instance_id
                AND status = 'ERROR'
                AND error_message LIKE '%Special Character Validation failed.%';

        END IF;

        COMMIT;
        p_status := 'SUCCESS';
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_error_message := 'Error in Special Character validation:  '
                               || sqlerrm
                               || ' '
                               || dbms_utility.format_error_backtrace;
            ROLLBACK;
            BEGIN
                UPDATE panduit_om_so_to_wms_tbl
                SET
                    status = 'ERROR',
                    error_message = p_error_message
                WHERE
                    oic_instance_id = p_instance_id;

                COMMIT;
            END;

    END;
END panduit_so_oracle_erp_to_wms_pkg;
/