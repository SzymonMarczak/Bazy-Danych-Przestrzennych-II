ALTER PROCEDURE cw3
	 @YearsAgo int 
AS
 SELECT 
	* 
 FROM FactCurrencyRate FCR
	JOIN DimCurrency DC
		ON DC.CurrencyKey = FCR.CurrencyKey
WHERE DC.CurrencyAlternateKey IN ('GBP', 'EUR')
	AND YEAR(Date) = YEAR(GETDATE()) - @YearsAgo

GO


exec cw3 @YearsAgo = 10

