-- CREATE unsigned SCHEMA
IF NOT EXISTS (SELECT * FROM [sys].[schemas] WHERE [name] = 'unsigned')
BEGIN
   EXECUTE ('CREATE SCHEMA [unsigned];');
END;
GO

IF EXISTS (SELECT * FROM [sys].[objects] WHERE [object_id] = OBJECT_ID(N'[unsigned].[Int32Multiply_Scalar]'))
BEGIN
   DROP FUNCTION [unsigned].[Int32Multiply_Scalar];
END;
GO

-- TRADITIONAL/IMPERATIVE IMPLEMENTATION OF BASIC UNSIGNED MULTIPLICATION ALGORITHM
CREATE FUNCTION [unsigned].[Int32Multiply_Scalar] (
   @LeftIN  INT,
   @RightIN INT
)
RETURNS INT
AS
BEGIN
   DECLARE @Result DECIMAL(19, 0);
   DECLARE @Left   DECIMAL(19, 0);
   DECLARE @Right  DECIMAL(19, 0);

   -- Initialize variables. Make sure @Right is actually the lesser of the two values coming in.
   -- Also, change the most significant bit from a sign bit to its corresponding unsigned value.
   SELECT @Result = 0,
          @Right  = (X.RHS & 2147483647) + (CASE (X.RHS & -2147483648) WHEN 0 THEN 0 ELSE 2147483648 END),
          @Left   = (X.LHS & 2147483647) + (CASE (X.LHS & -2147483648) WHEN 0 THEN 0 ELSE 2147483648 END)
   FROM   ( SELECT CASE WHEN (@RightIN < @LeftIN) THEN @RightIN ELSE @LeftIN  END AS RHS,
                   CASE WHEN (@RightIN < @LeftIN) THEN @LeftIN  ELSE @RightIN END AS LHS
          ) AS X;

   -- While there are still bits left in the @Right value...
   WHILE (@Right > 0)
   BEGIN
      -- If the least significant bit is 1...
      IF ((@Right % 2) > 0)
      BEGIN
         -- Add @Left to result
         SET @Result = (@Result + @Left) % 4294967296;
      END;

      -- Shift all bits down in @Right
      SET @Right = FLOOR(@Right / 2);

      -- Shift all bits up in @Left and keep only the lower 32 bits
      SET @Left = (@Left * 2) % 4294967296;
   END;

   -- Converting the most significant unsigned bit back to its corresponding sign value and return the product.
   RETURN CASE WHEN (@Result > 2147483647)
             THEN CONVERT(INT, (@Result - 2147483648)) | -2147483648
             ELSE CONVERT(INT, @Result)
          END;
END;
GO

IF EXISTS (SELECT * FROM [sys].[objects] WHERE [object_id] = OBJECT_ID(N'[unsigned].[Int32Multiply_Recursive]'))
BEGIN
   DROP FUNCTION [unsigned].[Int32Multiply_Recursive];
END;
GO

-- AN INLINE FUNCTION APPROACH THAT DOES NOT FULLY REMOVE THE IMPERATIVE LOGIC
CREATE FUNCTION [unsigned].[Int32Multiply_Recursive] (
   @LeftIN  INT,
   @RightIN INT
)
RETURNS TABLE
AS
RETURN
   (  WITH
      InitialValues
      AS (  SELECT CONVERT(DECIMAL(19, 0), 0) AS Result,
                   CONVERT(DECIMAL(19, 0), (X.RHS & 2147483647) + (CASE (X.RHS & -2147483648) WHEN 0 THEN 0 ELSE 2147483648 END)) AS RightValue,
                   CONVERT(DECIMAL(19, 0), (X.LHS & 2147483647) + (CASE (X.LHS & -2147483648) WHEN 0 THEN 0 ELSE 2147483648 END)) AS LeftValue
            FROM   ( SELECT CASE WHEN (@RightIN < @LeftIN) THEN @RightIN ELSE @LeftIN  END AS RHS,
                            CASE WHEN (@RightIN < @LeftIN) THEN @LeftIN  ELSE @RightIN END AS LHS
                   ) AS X
         ),
      WorkProducts
      AS (  SELECT SV.Result,
                   SV.LeftValue,
                   SV.RightValue
            FROM   InitialValues AS SV
            UNION ALL
            SELECT CASE WHEN ((WP.RightValue % 2) > 0)
                      THEN CONVERT(DECIMAL(19, 0), (WP.Result + WP.LeftValue) % 4294967296)
                      ELSE WP.Result
                   END AS Result,
                   CONVERT(DECIMAL(19, 0), (WP.LeftValue * 2) % 4294967296) AS LeftValue,
                   CONVERT(DECIMAL(19, 0), FLOOR(WP.RightValue / 2)) AS RightValue
            FROM   WorkProducts AS WP
            WHERE  WP.RightValue > 0
         )
      SELECT CASE WHEN (P.Result > 2147483647)
                THEN CONVERT(INT, (P.Result - 2147483648)) | -2147483648
                ELSE CONVERT(INT, P.Result)
             END AS ResultProduct
      FROM   WorkProducts AS P
      WHERE  P.RightValue = 0
   );
GO

-- THE FOLLOWING COMMENT BLOCK CONTAINS THE TEST CODE THAT HELPS EXPLAIN THE FULLY DECLARATIVE APPROACH
/*

DECLARE @LeftIN  INT;
DECLARE @RightIN INT;

SET @LeftIN  =  775321;
SET @RightIN = 1023447;

WITH
Inputs
AS (  SELECT CASE WHEN (@RightIN < @LeftIN) THEN @RightIN ELSE @LeftIN  END AS RHS,
             CASE WHEN (@RightIN < @LeftIN) THEN @LeftIN  ELSE @RightIN END AS LHS
   ),
Bits
AS (  SELECT -2147483648 AS Value, 1 AS [Sign] UNION ALL
      SELECT  1073741824 AS Value, 0 AS [Sign] UNION ALL
      SELECT   536870912 AS Value, 0 AS [Sign] UNION ALL
      SELECT   268435456 AS Value, 0 AS [Sign] UNION ALL
      SELECT   134217728 AS Value, 0 AS [Sign] UNION ALL
      SELECT    67108864 AS Value, 0 AS [Sign] UNION ALL
      SELECT    33554432 AS Value, 0 AS [Sign] UNION ALL
      SELECT    16777216 AS Value, 0 AS [Sign] UNION ALL
      SELECT     8388608 AS Value, 0 AS [Sign] UNION ALL
      SELECT     4194304 AS Value, 0 AS [Sign] UNION ALL
      SELECT     2097152 AS Value, 0 AS [Sign] UNION ALL
      SELECT     1048576 AS Value, 0 AS [Sign] UNION ALL
      SELECT      524288 AS Value, 0 AS [Sign] UNION ALL
      SELECT      262144 AS Value, 0 AS [Sign] UNION ALL
      SELECT      131072 AS Value, 0 AS [Sign] UNION ALL
      SELECT       65536 AS Value, 0 AS [Sign] UNION ALL
      SELECT       32768 AS Value, 0 AS [Sign] UNION ALL
      SELECT       16384 AS Value, 0 AS [Sign] UNION ALL
      SELECT        8192 AS Value, 0 AS [Sign] UNION ALL
      SELECT        4096 AS Value, 0 AS [Sign] UNION ALL
      SELECT        2048 AS Value, 0 AS [Sign] UNION ALL
      SELECT        1024 AS Value, 0 AS [Sign] UNION ALL
      SELECT         512 AS Value, 0 AS [Sign] UNION ALL
      SELECT         256 AS Value, 0 AS [Sign] UNION ALL
      SELECT         128 AS Value, 0 AS [Sign] UNION ALL
      SELECT          64 AS Value, 0 AS [Sign] UNION ALL
      SELECT          32 AS Value, 0 AS [Sign] UNION ALL
      SELECT          16 AS Value, 0 AS [Sign] UNION ALL
      SELECT           8 AS Value, 0 AS [Sign] UNION ALL
      SELECT           4 AS Value, 0 AS [Sign] UNION ALL
      SELECT           2 AS Value, 0 AS [Sign] UNION ALL
      SELECT           1 AS Value, 0 AS [Sign]
   )
      SELECT I.RHS                  AS RightValueRaw,
             B.Value                AS ShiftValue,
             I.LHS                  AS LeftValueRaw,
             P.Product              AS LeftValueShifted,
             P.Product % 4294967296 AS LeftValueShiftedLower32
      FROM   Inputs AS I
             INNER JOIN Bits AS B
             ON ((I.RHS & B.Value) != 0)
             CROSS APPLY ( SELECT CONVERT(DECIMAL(19, 0), CASE B.[Sign] WHEN 1 THEN 2147483648 ELSE B.Value END) AS ValueDecimal ) AS D
             CROSS APPLY ( SELECT CONVERT(DECIMAL(19, 0), I.LHS) * D.ValueDecimal AS Product ) AS P;

-- RightValueRaw          :       775321 =                    10111101010010011001
-- LeftValueRaw           :      1023447 =                    11111001110111010111
-- (A Single Shift Example)
-- ShiftValue             :       524288 =                    10000000000000000000
-- LeftValueShifted       : 536580980736 = 111110011101110101110000000000000000000
-- LeftValueShiftedLower32:   4005036032 =        11101110101110000000000000000000
GO

DECLARE @LeftIN  INT;
DECLARE @RightIN INT;

SET @LeftIN  =  775321;
SET @RightIN = 1023447;

WITH
Inputs
AS (  SELECT CASE WHEN (@RightIN < @LeftIN) THEN @RightIN ELSE @LeftIN  END AS RHS,
             CASE WHEN (@RightIN < @LeftIN) THEN @LeftIN  ELSE @RightIN END AS LHS
   ),
Bits
AS (  SELECT -2147483648 AS Value, 1 AS [Sign] UNION ALL
      SELECT  1073741824 AS Value, 0 AS [Sign] UNION ALL
      SELECT   536870912 AS Value, 0 AS [Sign] UNION ALL
      SELECT   268435456 AS Value, 0 AS [Sign] UNION ALL
      SELECT   134217728 AS Value, 0 AS [Sign] UNION ALL
      SELECT    67108864 AS Value, 0 AS [Sign] UNION ALL
      SELECT    33554432 AS Value, 0 AS [Sign] UNION ALL
      SELECT    16777216 AS Value, 0 AS [Sign] UNION ALL
      SELECT     8388608 AS Value, 0 AS [Sign] UNION ALL
      SELECT     4194304 AS Value, 0 AS [Sign] UNION ALL
      SELECT     2097152 AS Value, 0 AS [Sign] UNION ALL
      SELECT     1048576 AS Value, 0 AS [Sign] UNION ALL
      SELECT      524288 AS Value, 0 AS [Sign] UNION ALL
      SELECT      262144 AS Value, 0 AS [Sign] UNION ALL
      SELECT      131072 AS Value, 0 AS [Sign] UNION ALL
      SELECT       65536 AS Value, 0 AS [Sign] UNION ALL
      SELECT       32768 AS Value, 0 AS [Sign] UNION ALL
      SELECT       16384 AS Value, 0 AS [Sign] UNION ALL
      SELECT        8192 AS Value, 0 AS [Sign] UNION ALL
      SELECT        4096 AS Value, 0 AS [Sign] UNION ALL
      SELECT        2048 AS Value, 0 AS [Sign] UNION ALL
      SELECT        1024 AS Value, 0 AS [Sign] UNION ALL
      SELECT         512 AS Value, 0 AS [Sign] UNION ALL
      SELECT         256 AS Value, 0 AS [Sign] UNION ALL
      SELECT         128 AS Value, 0 AS [Sign] UNION ALL
      SELECT          64 AS Value, 0 AS [Sign] UNION ALL
      SELECT          32 AS Value, 0 AS [Sign] UNION ALL
      SELECT          16 AS Value, 0 AS [Sign] UNION ALL
      SELECT           8 AS Value, 0 AS [Sign] UNION ALL
      SELECT           4 AS Value, 0 AS [Sign] UNION ALL
      SELECT           2 AS Value, 0 AS [Sign] UNION ALL
      SELECT           1 AS Value, 0 AS [Sign]
   ),
PartialProducts
AS (  SELECT I.RHS                  AS RightValueRaw,
             B.Value                AS ShiftValue,
             I.LHS                  AS LeftValueRaw,
             P.Product              AS LeftValueShifted,
             P.Product % 4294967296 AS LeftValueShiftedLower32
      FROM   Inputs AS I
             INNER JOIN Bits AS B
             ON ((I.RHS & B.Value) != 0)
             CROSS APPLY ( SELECT CONVERT(DECIMAL(19, 0), CASE B.[Sign] WHEN 1 THEN 2147483648 ELSE B.Value END) AS ValueDecimal ) AS D
             CROSS APPLY ( SELECT CONVERT(DECIMAL(19, 0), I.LHS) * D.ValueDecimal AS Product ) AS P
   ),
PartialProductsSums
AS (  SELECT SUM(P.ShiftValue             ) AS SumOfShiftValue,
             SUM(P.LeftValueShifted       ) AS SumOfLeftValueShifted,
             SUM(P.LeftValueShiftedLower32) AS SumOfLeftValueShiftedLower32
      FROM   PartialProducts AS P
   ),
PartialProductsSumsLower32
AS (  SELECT PS.*,
             PS.SumOfLeftValueShifted        % 4294967296 AS Lower32BitsOfSumOfLeftValueShifted,
             PS.SumOfLeftValueShiftedLower32 % 4294967296 AS Lower32BitsOfSumOfLeftValueShiftedLower32
      FROM   PartialProductsSums AS PS
   )
SELECT L.*,
       CASE WHEN (L.Lower32BitsOfSumOfLeftValueShiftedLower32 > 2147483647)
          THEN CONVERT(INT, (L.Lower32BitsOfSumOfLeftValueShiftedLower32 - 2147483648)) | -2147483648
          ELSE CONVERT(INT, L.Lower32BitsOfSumOfLeftValueShiftedLower32)
       END AS SignAdjustedLower32BitsOfSumOfLeftValueShiftedLower32
FROM   PartialProductsSumsLower32 AS L;

*/

IF EXISTS (SELECT * FROM [sys].[objects] WHERE [object_id] = OBJECT_ID(N'[unsigned].[Int32Multiply]'))
BEGIN
   DROP FUNCTION [unsigned].[Int32Multiply];
END;
GO

CREATE FUNCTION [unsigned].[Int32Multiply] (
   @LeftIN  INT,
   @RightIN INT
)
RETURNS TABLE
AS
RETURN
   (  WITH
      Inputs
      AS (  SELECT CASE WHEN (@RightIN < @LeftIN) THEN @RightIN ELSE @LeftIN  END AS RHS,
                   CASE WHEN (@RightIN < @LeftIN) THEN @LeftIN  ELSE @RightIN END AS LHS
         ),
      Bits
      AS (  SELECT -2147483648 AS Value, 1 AS [Sign] UNION ALL
            SELECT  1073741824 AS Value, 0 AS [Sign] UNION ALL
            SELECT   536870912 AS Value, 0 AS [Sign] UNION ALL
            SELECT   268435456 AS Value, 0 AS [Sign] UNION ALL
            SELECT   134217728 AS Value, 0 AS [Sign] UNION ALL
            SELECT    67108864 AS Value, 0 AS [Sign] UNION ALL
            SELECT    33554432 AS Value, 0 AS [Sign] UNION ALL
            SELECT    16777216 AS Value, 0 AS [Sign] UNION ALL
            SELECT     8388608 AS Value, 0 AS [Sign] UNION ALL
            SELECT     4194304 AS Value, 0 AS [Sign] UNION ALL
            SELECT     2097152 AS Value, 0 AS [Sign] UNION ALL
            SELECT     1048576 AS Value, 0 AS [Sign] UNION ALL
            SELECT      524288 AS Value, 0 AS [Sign] UNION ALL
            SELECT      262144 AS Value, 0 AS [Sign] UNION ALL
            SELECT      131072 AS Value, 0 AS [Sign] UNION ALL
            SELECT       65536 AS Value, 0 AS [Sign] UNION ALL
            SELECT       32768 AS Value, 0 AS [Sign] UNION ALL
            SELECT       16384 AS Value, 0 AS [Sign] UNION ALL
            SELECT        8192 AS Value, 0 AS [Sign] UNION ALL
            SELECT        4096 AS Value, 0 AS [Sign] UNION ALL
            SELECT        2048 AS Value, 0 AS [Sign] UNION ALL
            SELECT        1024 AS Value, 0 AS [Sign] UNION ALL
            SELECT         512 AS Value, 0 AS [Sign] UNION ALL
            SELECT         256 AS Value, 0 AS [Sign] UNION ALL
            SELECT         128 AS Value, 0 AS [Sign] UNION ALL
            SELECT          64 AS Value, 0 AS [Sign] UNION ALL
            SELECT          32 AS Value, 0 AS [Sign] UNION ALL
            SELECT          16 AS Value, 0 AS [Sign] UNION ALL
            SELECT           8 AS Value, 0 AS [Sign] UNION ALL
            SELECT           4 AS Value, 0 AS [Sign] UNION ALL
            SELECT           2 AS Value, 0 AS [Sign] UNION ALL
            SELECT           1 AS Value, 0 AS [Sign]
         ),
      PartialProducts
      AS (  SELECT (P.Product % 4294967296) AS PartialProduct
            FROM   Inputs AS I
                   INNER JOIN Bits AS B
                   ON ((I.RHS & B.Value) != 0)
                   CROSS APPLY ( SELECT CONVERT(DECIMAL(19, 0), CASE B.[Sign] WHEN 1 THEN 2147483648 ELSE B.Value END) AS ValueDecimal ) AS D
                   CROSS APPLY ( SELECT CONVERT(DECIMAL(19, 0), I.LHS) * D.ValueDecimal AS Product ) AS P
         )
      SELECT CASE WHEN (F.Product > 2147483647)
                THEN CONVERT(INT, (F.Product - 2147483648)) | -2147483648
                ELSE CONVERT(INT, F.Product)
             END AS Result
      FROM   ( SELECT SUM(P.PartialProduct) % 4294967296 AS Product
               FROM   PartialProducts AS P
             ) AS F
   );
GO

-- THE FOLLOWING COMMENT BLOCK CONTAINS THE PERFORMANCE TESTS FOR ALL THREE VARIATIONS
/*
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Test traditional imperative scalar function.
WITH
RowBasis
AS (  SELECT 1 AS N UNION ALL
      SELECT 1 AS N UNION ALL
      SELECT 1 AS N UNION ALL
      SELECT 1 AS N
   ),
NumberTable
AS (  SELECT ROW_NUMBER() OVER (PARTITION BY 0 ORDER BY A.N) AS Number
      FROM   RowBasis AS A
             CROSS JOIN RowBasis AS B
             CROSS JOIN RowBasis AS C
             CROSS JOIN RowBasis AS D
             CROSS JOIN RowBasis AS E
             CROSS JOIN RowBasis AS F
             CROSS JOIN RowBasis AS G
             CROSS JOIN RowBasis AS H
             CROSS JOIN RowBasis AS I
             CROSS JOIN RowBasis AS J
   )
SELECT T.Number,
       [unsigned].[Int32Multiply_Scalar](CONVERT(BIGINT, T.Number), 197387)
FROM   NumberTable AS T;
GO

-- Test recursive inline function.
WITH
RowBasis
AS (  SELECT 1 AS N UNION ALL
      SELECT 1 AS N UNION ALL
      SELECT 1 AS N UNION ALL
      SELECT 1 AS N
   ),
NumberTable
AS (  SELECT ROW_NUMBER() OVER (PARTITION BY 0 ORDER BY A.N) AS Number
      FROM   RowBasis AS A
             CROSS JOIN RowBasis AS B
             CROSS JOIN RowBasis AS C
             CROSS JOIN RowBasis AS D
             CROSS JOIN RowBasis AS E
             CROSS JOIN RowBasis AS F
             CROSS JOIN RowBasis AS G
             CROSS JOIN RowBasis AS H
             CROSS JOIN RowBasis AS I
             CROSS JOIN RowBasis AS J
   )
SELECT *
FROM   NumberTable AS T
       CROSS APPLY [unsigned].[Int32Multiply_Recursive](CONVERT(BIGINT, T.Number), 197387) AS S;
GO

-- Test non-recursive inline function.
WITH
RowBasis
AS (  SELECT 1 AS N UNION ALL
      SELECT 1 AS N UNION ALL
      SELECT 1 AS N UNION ALL
      SELECT 1 AS N
   ),
NumberTable
AS (  SELECT ROW_NUMBER() OVER (PARTITION BY 0 ORDER BY A.N) AS Number
      FROM   RowBasis AS A
             CROSS JOIN RowBasis AS B
             CROSS JOIN RowBasis AS C
             CROSS JOIN RowBasis AS D
             CROSS JOIN RowBasis AS E
             CROSS JOIN RowBasis AS F
             CROSS JOIN RowBasis AS G
             CROSS JOIN RowBasis AS H
             CROSS JOIN RowBasis AS I
             CROSS JOIN RowBasis AS J
   )
SELECT T.Number, S.Result
FROM   NumberTable AS T
       CROSS APPLY [unsigned].[Int32Multiply](CONVERT(BIGINT, T.Number), 197387) AS S;
GO
*/
