IF NOT EXISTS(SELECT * FROM sysobjects WHERE type = 'U' AND name = 'stg_dimemp')
BEGIN
	SELECT 
		EMPLOYEEKEY
		,FIRSTNAME
		,LASTNAME
		,TITLE 
	INTO AdventureWorksDW2019.dbo.stg_dimemp
	FROM DimEmployee
	WHERE EMPLOYEEKEY BETWEEN 270 AND 275
END

CREATE TABLE dbo.scd_dimemp ( 
EmployeeKey int , 
FirstName nvarchar(50) not null, 
LastName nvarchar(50) not null, 
Title nvarchar(50), 
StartDate datetime, 
EndDate datetime); 
INSERT INTO dbo.scd_dimemp (EmployeeKey, FirstName, LastName, Title, StartDate, EndDate) 
SELECT EmployeeKey, FirstName, LastName, Title, StartDate, EndDate 
FROM dbo.DimEmployee 
WHERE EmployeeKey >= 270 AND EmployeeKey <= 275


update STG_DimEmp 
set LastName = 'Nowak' 
where EmployeeKey = 270; 
update STG_DimEmp 
set TITLE = 'Senior Design Engineer' 
where EmployeeKey = 274; 


update STG_DimEmp 
set FIRSTNAME = 'Ryszard' 
where EmployeeKey = 275