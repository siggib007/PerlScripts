create table tblservertecs (
ID int not null auto_increment,
vcDevname varchar(50),
vcIPAddr varchar(20),
vcComStr varchar(50),
vcLocation varchar(250),
Primary key (ID));


create table tblDevPower (
iPowerID int not null auto_increment,
dtMeasuredTime datetime, 
vcDevName varchar(50),
vcIPAddr varchar(20),
vcSysName varchar(200),
vcOutletID varchar(5),
vcOutletName varchar(50),
vcOutletStatus varchar(20),
vcOutletLoadStatus varchar(20),
fOutletLoadValue float,
vcLocation varchar(250),
Primary key (iPowerID)
);

create table tblErrorLog (
iErrID int not null auto_increment,
dtErrorTime datetime,
vcErrType varchar(50),
vcErrDescr varchar(500),
Primary key (iErrID)
);

alter view vwPowerBTU as select dtMeasuredTime, vcDevName, vcIPAddr, vcSysName, vclocation, vcOutletID, 
vcOutletName, vcOutletLoadStatus, fOutletLoadValue, fOutletLoadValue * 165 BTUs
from tblDevPower
where vcOutletStatus = 'on';
