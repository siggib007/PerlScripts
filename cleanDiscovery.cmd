bench	/\(bc\)#/
server discovery local 10.20.7.26	/\(bc\)#/
server discovery network 10.20.7.26	/\(bc\)#/
server discovery universal 10.20.7.26	/\(bc\)#/
no server discovery local 10.230.9.151	/\(bc\)#/
no server discovery network 10.230.9.151	/\(bc\)#/
no server discovery universal 10.230.9.151	/\(bc\)#/
exit	/WARNING/
y	$enPrompt
conf t	/\(config\)#/
server discovery local 10.20.7.26	/\(config\)#/
server discovery network 10.20.7.26	/\(config\)#/
server discovery universal 10.20.7.26	/\(config\)#/
no server discovery local 10.230.9.151	/\(config\)#/
no server discovery network 10.230.9.151	/\(config\)#/
no server discovery universal 10.230.9.151	/\(config\)#/
exit	$enPrompt
write	/saved./
exit	$prompt