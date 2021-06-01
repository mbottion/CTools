set feedback off
set serveroutput on
begin
  if (upper('1') in ('USAGE','HELP','-?','-H'))
  then
    raise_application_error(-20000,'
+---------------------------------------------------------------------------------------
| Usage:
|    OPACallsPerMinuteINPerfs.sql [start] [end] [engine] [interval]
|   
|      Agregates OPA Execution from the dashbord en shos for each interval :
|          - Calls (packets per interval/minute)
|          - Cases (per interval/minute)
|          - Miin and max of OPA globale processing(viewed from the applications)
|          - An "old-school' graph
|
|   Parameters :
|       start    : Analysis start date (dd/mm/yyyy [hh24:mi:ss])      - Default : Noon (Today or yesterday)
|       end      : Analysis end date   (dd/mm/yyyy [hh24:mi:ss])      - Default : now
|       engine   : Engine name                                        - Default : %
|       interval : Interval wiideness (in seconds)                    - Default : 60
|       
+---------------------------------------------------------------------------------------
       ');
  end if ;
end ;
/
-- -----------------------------------------------------------------
-- Parameters (use P1 -- PN, to ease script test in SQL*Dev)
-- -----------------------------------------------------------------
P1=&1
P2=&2
P3=&3
P4=&4
--
--  Analysis start date : Default (If before noon, noon yesterday, otherwise noon)
--
define start_date_FR="case when '&P1' is null then round(sysdate)-0.5 else to_date('&P1','dd/mm/yyyy hh24:mi:ss') end"
--
--  Analysis end date : default now
--
define end_date_FR="case when '&P2' is null then sysdate else to_date('&P2','dd/mm/yyyy hh24:mi:ss') end"
--
--  Engine name
--
define engineName="case when '&P3' is null then '%' else '&P3' end"
--
-- Case number grouping by interval
--
define interval_size="case when '&P5' is null then 50 else to_number('&P5') end"


-- -----------------------------------------------------------------
-- Generic SCript - Change values to change the analysis
-- -----------------------------------------------------------------
define analysed_value="total_opa"
-- -----------------------------------------------------------------
-- Columns formats
-- -----------------------------------------------------------------
column ord                 noprint
column start_period        format    a20      trunc heading "Start Period"
column end_period          format    a20      trunc heading "End Periodd"
column nb_calls            format    a10      trunc heading "Calls"
column nb_calls_per_minute format    a10      trunc heading "Calls per minute"
column nb_cases            format    a15      trunc heading "Cases"
column nb_cases_per_minute format    a10      trunc heading "Cases per minute"
column avg_time            format    a10      trunc heading "Avg Time"
column max_time            format    a10      trunc heading "Max Time"
column avg_time_bar        format    a60      trunc heading "Avg (full=60+ sec)"
column max_time_bar        format    a120      trunc heading "Max (full=120+ sec)

Prompt ====================================================================================
Prompt &report_title
Prompt ====================================================================================

-- -----------------------------------------------------------------
-- SQL
-- -----------------------------------------------------------------
with allHist as (
                SELECT
                    'TEC' AS SCHEMA_NAME      , INSTANCE_ENGINE_NAME     , ENGINE_NAME        , PRESTATION_NAME
                  , TASK_NUM                  , LOT_NUM                  , START_BUILD_JSON   , END_BUILD_JSON
                  , START_CALL_ENGINE         , END_CALL_ENGINE          , START_READ_JSON    , END_READ_JSON
                  , STATUS,SUMMARY            , MONTH_LEVEL              , ID_TDB_INTERFACE   , IN_JSON_OPA_SIZE_MB
                  , ROUND(dbms_lob.getlength(IN_JSON_OPA) / 1024 / 1024, 2) AS SIZE_IN_MB 
                  , ROUND(dbms_lob.getlength(OUT_JSON_OPA) / 1024 / 1024, 2) AS SIZE_OUT_MB
                FROM TEC.S_DASHBOARD_HIST_OPA
                UNION
                SELECT
                    'LIQ1' AS SCHEMA_NAME     , INSTANCE_ENGINE_NAME     , ENGINE_NAME        , PRESTATION_NAME
                  , TASK_NUM                  , LOT_NUM                  , START_BUILD_JSON   , END_BUILD_JSON
                  , START_CALL_ENGINE         , END_CALL_ENGINE          , START_READ_JSON    , END_READ_JSON
                  , STATUS,SUMMARY            , MONTH_LEVEL              , ID_TDB_INTERFACE   , IN_JSON_OPA_SIZE_MB
                  , ROUND(dbms_lob.getlength(IN_JSON_OPA) / 1024 / 1024, 2) AS SIZE_IN_MB 
                  , ROUND(dbms_lob.getlength(OUT_JSON_OPA) / 1024 / 1024, 2) AS SIZE_OUT_MB
                FROM LIQ1.S_DASHBOARD_HIST_OPA
                UNION
                SELECT
                    'LIQ2' AS SCHEMA_NAME     , INSTANCE_ENGINE_NAME     , ENGINE_NAME        , PRESTATION_NAME
                  , TASK_NUM                  , LOT_NUM                  , START_BUILD_JSON   , END_BUILD_JSON
                  , START_CALL_ENGINE         , END_CALL_ENGINE          , START_READ_JSON    , END_READ_JSON
                  , STATUS,SUMMARY            , MONTH_LEVEL              , ID_TDB_INTERFACE   , IN_JSON_OPA_SIZE_MB
                  , ROUND(dbms_lob.getlength(IN_JSON_OPA) / 1024 / 1024, 2) AS SIZE_IN_MB 
                  , ROUND(dbms_lob.getlength(OUT_JSON_OPA) / 1024 / 1024, 2) AS SIZE_OUT_MB
                FROM LIQ2.S_DASHBOARD_HIST_OPA
                UNION
                SELECT
                    'LIQF1' AS SCHEMA_NAME    , INSTANCE_ENGINE_NAME     , ENGINE_NAME        , PRESTATION_NAME
                  , TASK_NUM                  , LOT_NUM                  , START_BUILD_JSON   , END_BUILD_JSON
                  , START_CALL_ENGINE         , END_CALL_ENGINE          , START_READ_JSON    , END_READ_JSON
                  , STATUS,SUMMARY            , MONTH_LEVEL              , ID_TDB_INTERFACE   , IN_JSON_OPA_SIZE_MB
                  , ROUND(dbms_lob.getlength(IN_JSON_OPA) / 1024 / 1024, 2) AS SIZE_IN_MB
                  , ROUND(dbms_lob.getlength(OUT_JSON_OPA) / 1024 / 1024, 2) AS SIZE_OUT_MB
                FROM LIQF1.S_DASHBOARD_HIST_OPA
                UNION
                SELECT
                    'LIQF2' AS SCHEMA_NAME    , INSTANCE_ENGINE_NAME     , ENGINE_NAME        , PRESTATION_NAME
                  , TASK_NUM                  , LOT_NUM                  , START_BUILD_JSON   , END_BUILD_JSON
                  , START_CALL_ENGINE         , END_CALL_ENGINE          , START_READ_JSON    , END_READ_JSON
                  , STATUS,SUMMARY            , MONTH_LEVEL              , ID_TDB_INTERFACE   , IN_JSON_OPA_SIZE_MB
                  , ROUND(dbms_lob.getlength(IN_JSON_OPA) / 1024 / 1024, 2) AS SIZE_IN_MB 
                  , ROUND(dbms_lob.getlength(OUT_JSON_OPA) / 1024 / 1024, 2) AS SIZE_OUT_MB
                FROM LIQF2.S_DASHBOARD_HIST_OPA
                UNION
                SELECT
                    'ACE1' AS SCHEMA_NAME     , INSTANCE_ENGINE_NAME     , ENGINE_NAME        , PRESTATION_NAME
                  , TASK_NUM                  , LOT_NUM                  , START_BUILD_JSON   , END_BUILD_JSON
                  , START_CALL_ENGINE         , END_CALL_ENGINE          , START_READ_JSON    , END_READ_JSON
                  , STATUS,SUMMARY            , MONTH_LEVEL              , ID_TDB_INTERFACE   , IN_JSON_OPA_SIZE_MB
                  , ROUND(dbms_lob.getlength(IN_JSON_OPA) / 1024 / 1024, 2) AS SIZE_IN_MB 
                  , ROUND(dbms_lob.getlength(OUT_JSON_OPA) / 1024 / 1024, 2) AS SIZE_OUT_MB
                FROM ACE1.S_DASHBOARD_HIST_OPA
                UNION
                SELECT
                    'SYN1' AS SCHEMA_NAME     , INSTANCE_ENGINE_NAME     , ENGINE_NAME        , PRESTATION_NAME
                  , TASK_NUM                  , LOT_NUM                  , START_BUILD_JSON   , END_BUILD_JSON
                  , START_CALL_ENGINE         , END_CALL_ENGINE          , START_READ_JSON    , END_READ_JSON
                  , STATUS,SUMMARY            , MONTH_LEVEL              , ID_TDB_INTERFACE   , IN_JSON_OPA_SIZE_MB
                  , ROUND(dbms_lob.getlength(IN_JSON_OPA) / 1024 / 1024, 2) AS SIZE_IN_MB 
                  , ROUND(dbms_lob.getlength(OUT_JSON_OPA) / 1024 / 1024, 2) AS SIZE_OUT_MB
                FROM SYN1.S_DASHBOARD_HIST_OPA
                )
,cleanHist as (
      SELECT  /*+ PARALLEL */
         ID_TDB_INTERFACE
        ,ENGINE_NAME
        ,start_call_engine
        ,(trunc(start_call_engine) - to_date('01/01/1970','dd/mm/yyyy'))*24*3600+to_number(to_char(start_call_engine,'SSSSS')) secs_since_epoch
        ,EXTRACT(SECOND FROM(END_CALL_ENGINE-START_CALL_ENGINE) DAY TO SECOND) AS TOTAL_OPA
        ,to_number(REPLACE(TRIM(SUBSTR(SUMMARY,INSTR(SUMMARY,':',1, 1)+1, INSTR(SUMMARY,'-',1, 2) -INSTR(SUMMARY,':',1, 1)-1)),',','.')) AS CasesRead
        ,to_number(REPLACE(TRIM(SUBSTR(SUMMARY,INSTR(SUMMARY,':',1, 2)+1, INSTR(SUMMARY,'-',1, 3) -INSTR(SUMMARY,':',1, 2)-1)),',','.')) AS CasesProcessed
        ,TO_NUMBER(REPLACE(TRIM(SUBSTR(SUMMARY,INSTR(SUMMARY,':',1, 3)+1, INSTR(SUMMARY,'-',1, 4) -INSTR(SUMMARY,':',1, 3)-1)),',','.')) AS CasesIgnored
        ,to_number(REPLACE(TRIM(SUBSTR(SUMMARY,INSTR(SUMMARY,':',1, 4)+1, INSTR(SUMMARY,'-',1, 5) -INSTR(SUMMARY,':',1, 4)-1)),',','.')) AS ProcessorDurationSec
        ,REPLACE(TRIM(SUBSTR(SUMMARY,INSTR(SUMMARY,':',1, 5)+1, LENGTH(SUMMARY) -INSTR(SUMMARY,':',1, 5))),',','.')                      AS ProcessorCasesPerSec
        ,summary
        ,size_in_mb
        ,size_out_mb
        ,start_build_json
      FROM  AllHist
      WHERE   STATUS ='Completed'      AND SUMMARY NOT LIKE '%ORA-%'
      AND START_BUILD_JSON >= &start_date_FR                     
      AND START_BUILD_JSON <= &end_date_FR
      AND ENGINE_NAME like &engineName
      )
,AllData as (
  SELECT
     TO_TIMESTAMP('1970-01-01 00:00:00.000', 'YYYY-MM-DD hh24:mi:SS.FF3')  
                 + numtodsinterval(floor((secs_since_epoch/&interval_size))*&interval_size, 'SECOND') start_period
    ,TO_TIMESTAMP('1970-01-01 00:00:00.000', 'YYYY-MM-DD hh24:mi:SS.FF3')  
                 + numtodsinterval((floor((secs_since_epoch/&interval_size)+1)*&interval_size)-1, 'SECOND') end_period
    ,ch2.*
  from
    CleanHist ch2
  )
select
   to_char(start_period,'dd/mm/yyyy hh24:mi:ss')                start_period
  ,to_char(end_period,'dd/mm/yyyy hh24:mi:ss')                  end_period
  ,count(*)                                                     nb_calls
  ,to_char(count(*)/(&interval_size/60),'999D99')               nb_calls_per_minute
  ,to_char(sum(casesRead),'999G999')                            nb_cases
  ,to_char(sum(casesRead)/(&interval_size/60),'999G999D99')     nb_cases_per_minute
  ,to_char(avg(total_opa),'999D99')                             avg_time
  ,to_char(max(total_opa),'999D99')                             max_time
  ,rpad('=',ceil(avg(total_opa)),'=')                           avg_time_bar
  ,rpad('=',ceil(max(total_opa)),'=')                           max_time_bar
from 
  allData
group by
   start_period
  ,end_period
having
  max(total_opa) > 20
order by start_period
/


