ALTER TABLE tblsubnets
CHANGE vcRegion vcMarket varchar(100) COLLATE 'latin1_swedish_ci' NULL AFTER iSubnetEnd,
CHANGE vcMarket vcSite varchar(100) COLLATE 'latin1_swedish_ci' NULL AFTER vcMarket;

ALTER TABLE tblStatus
CHANGE vcCity vcMarket varchar(50) COLLATE 'latin1_swedish_ci' NULL AFTER dtUpdatedAt,
CHANGE vcMarket vcSite varchar(50) COLLATE 'latin1_swedish_ci' NULL AFTER vcMarket;

ALTER TABLE tblDevices
ADD iIPAddr int NOT NULL AFTER vcIPaddr,
ADD vcMarket varchar(100) COLLATE 'latin1_swedish_ci' NOT NULL AFTER iIPAddr,
ADD vcsysLocation varchar(150) COLLATE 'latin1_swedish_ci' NULL AFTER vcSysObjectID,
ADD vcSite varchar(100) COLLATE 'latin1_swedish_ci' NOT NULL AFTER vcMarket;

CREATE TABLE tblDeadDNS (
  vcDNSName varchar(100) NOT NULL,
  vcIPAddr varchar(25) NOT NULL,
  dtTimeStamp datetime NOT NULL
) ENGINE='InnoDB';

CREATE TABLE tblLocationTypes (
  iLocationID int NOT NULL AUTO_INCREMENT PRIMARY KEY,
  vcLocationName varchar(150) NOT NULL,
  vcWhere varchar(300) NOT NULL
) ENGINE='InnoDB';

INSERT INTO tblLocationTypes (iLocationID, vcLocationName, vcWhere) VALUES
(1,	'TransPop',	'vcSite like \'9_99\''),
(2,	'Agg Pop',	'vcSite REGEXP \'[0-9]{4}\' and vcSite not like \'9_99\''),
(3,	'Core',	'vcSite NOT REGEXP \'[0-9]{4}\''),
(4,	'All Pops',	'vcSite REGEXP \'[0-9]{4}\'');