ALTER TABLE tbldevpower
ADD vcRackName varchar(50) NULL AFTER dtMeasuredTime,
ADD vcFeed varchar(50) COLLATE 'latin1_swedish_ci' NULL AFTER vcSysName;