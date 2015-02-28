CREATE TABLE tblConf (
  iMaxRecords int NOT NULL,
  vcCommunity varchar(50) NOT NULL,
  iConLevel tinyint NOT NULL,
  iLogLevel tinyint NOT NULL,
  vcEmail varchar(5) NOT NULL,
  vcTable varchar(50) NOT NULL,
  iCurScriptNo int NOT NULL,
  iCurNetID int NOT NULL,
  iStartHour tinyint NOT NULL,
  iDayInterval tinyint NOT NULL,
  dtLastRun date NOT NULL
) ENGINE='InnoDB'