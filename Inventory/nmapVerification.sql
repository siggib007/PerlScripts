select * from inventory.tblDevices where vcIPaddr not in (select vcIPaddr from Testinventory.tblDevices)
and (vcSSH = 'Success' or vcTelnet = 'Success' or vcHTTP = 'Success' or vcHTTPs = 'Success') and dtUpdatedAt > '2011-03-17'