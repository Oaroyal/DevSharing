-- CREATING TEST DATA

CREATE TABLE #Org (
   OrgID       INT IDENTITY(1, 1) NOT NULL PRIMARY KEY CLUSTERED,
   OrgIDOwner  INT                    NULL,
   OrgType     VARCHAR(16)        NOT NULL,   -- HEADQUARTERS, DIVISION, SATELLITE, OUTLET, WAREHOUSE
   Region      VARCHAR(64)        NOT NULL,   -- CALIFORNIA-A, CALIFORNIA-B, TEXAS-A, TEXAS-B, TEXAS-C, MAINE, DELAWARE, OREGON, NEVADA, FLORIDA, GEORGIA
   Performance VARCHAR(16)        NOT NULL,   -- A, B, C, D, E, F
   Established DATETIME           NOT NULL,
   MaxStaff    INT                NOT NULL
);
GO

WITH
RowBasis AS
(  SELECT 1 AS N UNION ALL
   SELECT 2 AS N UNION ALL
   SELECT 3 AS N UNION ALL
   SELECT 4 AS N
),
RowExpansion AS
(  SELECT   A.N
          + ((B.N - 1) * 4)
          + ((C.N - 1) * 16)
          + ((D.N - 1) * 64)
          + ((E.N - 1) * 256)
          + ((F.N - 1) * 1024)
          + ((G.N - 1) * 4096) AS X
   FROM   RowBasis AS A
          CROSS JOIN RowBasis AS B
          CROSS JOIN RowBasis AS C
          CROSS JOIN RowBasis AS D
          CROSS JOIN RowBasis AS E
          CROSS JOIN RowBasis AS F
          CROSS JOIN RowBasis AS G
),
RandomBasis AS
(  SELECT E.X AS SourceNumber,
          (  (RAND(E.X) * 9999999.9999999)
           - CONVERT(BIGINT, (RAND(E.X) * 9999999.9999999))
          ) AS RandomNumber
   FROM   RowExpansion AS E
),
OrgBasis AS
(  SELECT R.SourceNumber,
          CASE (CONVERT(INT, (R.RandomNumber * 397.0)) %  5)
             WHEN 0 THEN NULL
             ELSE CONVERT(INT, (CONVERT(BIGINT, (R.RandomNumber * 97534.0)) % 16384))
          END AS OrgIDOwner,
          CASE (CONVERT(INT, (R.RandomNumber * 397.0)) %  5)
             WHEN 0 THEN 'HEADQUARTERS'
             WHEN 1 THEN 'DIVISION'
             WHEN 2 THEN 'SATELLITE'
             WHEN 3 THEN 'OUTLET'
             WHEN 4 THEN 'WAREHOUSE'
          END AS OrgType,
          CASE (CONVERT(INT, (R.RandomNumber * 937.0)) % 11)
             WHEN  0 THEN 'CALIFORNIA-A'
             WHEN  1 THEN 'CALIFORNIA-B'
             WHEN  2 THEN 'TEXAS-A'
             WHEN  3 THEN 'TEXAS-B'
             WHEN  4 THEN 'TEXAS-C'
             WHEN  5 THEN 'MAINE'
             WHEN  6 THEN 'DELAWARE'
             WHEN  7 THEN 'OREGON'
             WHEN  8 THEN 'NEVADA'
             WHEN  9 THEN 'FLORIDA'
             WHEN 10 THEN 'GEORGIA'
          END AS Region,
          CASE (CONVERT(INT, (R.RandomNumber * 297.0)) %  6)
             WHEN 0 THEN 'A'
             WHEN 1 THEN 'B'
             WHEN 2 THEN 'C'
             WHEN 3 THEN 'D'
             WHEN 4 THEN 'E'
             WHEN 5 THEN 'F'
          END AS Performance,
          DATEADD(DAY, (CONVERT(INT, (R.RandomNumber * 32982.0)) % 7300), '1985-01-01') AS Established,
          (CONVERT(INT, (R.RandomNumber * 857.0)) +  3) AS Staff
   FROM   RandomBasis AS R
)
INSERT INTO #Org (
   OrgIDOwner,
   OrgType,
   Region,
   Performance,
   Established,
   MaxStaff )
SELECT B.OrgIDOwner,
       B.OrgType,
       B.Region,
       B.Performance,
       B.Established,
       B.Staff
FROM   OrgBasis AS B
ORDER BY SourceNumber;
GO

CREATE UNIQUE NONCLUSTERED INDEX IX_Org1 ON #Org ( OrgType, Established, OrgID );
CREATE UNIQUE NONCLUSTERED INDEX IX_Org2 ON #Org ( OrgType, OrgIDOwner,  OrgID );
GO

-- THIS STATEMENT USES THE SEED OrgIDOwner TO FIND THE CLOSEST HEADQUARTER RECORD
-- TO ASSIGN TO EACH DIVISION (THIS TAKES A LITTLE TIME AS I HAVE NOT OPTIMIZED IT FOR PERFORMANCE)
UPDATE D
SET    D.OrgIDOwner = H.OrgID
-- SELECT *
FROM   #Org AS D
       INNER JOIN #Org AS H
       ON (D.OrgIDOwner > H.OrgID)
WHERE  D.OrgType = 'DIVISION'
AND    H.OrgType = 'HEADQUARTERS'
AND    NOT EXISTS
       ( SELECT *
         FROM   #Org AS X
         WHERE  X.OrgType = 'HEADQUARTERS'
         AND    X.OrgID   < D.OrgIDOwner
         AND    X.OrgID   > H.OrgID
       );
GO

-- THIS STATEMENT USES THE SEED OrgIDOwner TO FIND THE CLOSEST DIVISION RECORD
-- TO ASSIGN TO EACH OUTLET, WAREHOUSE, AND SATELLITE (THIS TAKES A LITTLE TIME AS I HAVE NOT OPTIMIZED IT FOR PERFORMANCE)
UPDATE Z
SET    Z.OrgIDOwner = D.OrgID
-- SELECT *
FROM   #Org AS Z
       INNER JOIN #Org AS D
       ON (Z.OrgIDOwner > D.OrgID)
WHERE  Z.OrgType IN ('OUTLET', 'WAREHOUSE', 'SATELLITE')
AND    D.OrgType =  'DIVISION'
AND    NOT EXISTS
       ( SELECT *
         FROM   #Org AS X
         WHERE  X.OrgType = 'DIVISION'
         AND    X.OrgID   < Z.OrgIDOwner
         AND    X.OrgID   > D.OrgID
       );
GO

-- SHOW EACH ORG RECORD AND HOW MANY MEMBERS HAVE BEEN ASSIGNED TO IT
SELECT X.*,
       ( SELECT COUNT(*) FROM #Org AS Z WHERE Z.OrgIDOwner = X.OrgID ) AS MemberCount
FROM   #Org AS X;

-- SHOW ALL HEADQUARTERS AND DIVISION RECORDS THAT HAVE A MEMBER
SELECT *
FROM   #Org AS X
WHERE  X.OrgType IN ('HEADQUARTERS', 'DIVISION')
AND    EXISTS
       ( SELECT *
         FROM   #Org AS Z
         WHERE  Z.OrgIDOwner = X.OrgID
       );

-- SHOW ALL HEADQUARTERS AND DIVISION RECORDS THAT HAVE NO MEMBERS
SELECT *
FROM   #Org AS X
WHERE  X.OrgType IN ('HEADQUARTERS', 'DIVISION')
AND    NOT EXISTS
       ( SELECT *
         FROM   #Org AS Z
         WHERE  Z.OrgIDOwner = X.OrgID
       );
GO

-- CLEAN UP
DROP TABLE #Org;
GO
