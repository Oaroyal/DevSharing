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
AS (  SELECT CONVERT(DECIMAL(19, 0), (I.RHS & 2147483647) + (CASE (I.RHS & -2147483648) WHEN 0 THEN 0 ELSE 2147483648 END)) AS RHS,
             CONVERT(DECIMAL(19, 0), (I.LHS & 2147483647) + (CASE (I.LHS & -2147483648) WHEN 0 THEN 0 ELSE 2147483648 END)) AS LHS
      FROM   ( SELECT CASE WHEN (@RightIN < @LeftIN) THEN @RightIN ELSE @LeftIN  END AS RHS,
                      CASE WHEN (@RightIN < @LeftIN) THEN @LeftIN  ELSE @RightIN END AS LHS
             ) I
   ),
Bits
AS (  SELECT CONVERT(DECIMAL(19, 0), 2147483648) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0), 1073741824) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),  536870912) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),  268435456) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),  134217728) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),   67108864) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),   33554432) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),   16777216) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),    8388608) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),    4194304) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),    2097152) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),    1048576) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),     524288) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),     262144) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),     131072) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),      65536) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),      32768) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),      16384) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),       8192) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),       4096) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),       2048) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),       1024) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),        512) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),        256) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),        128) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),         64) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),         32) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),         16) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),          8) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),          4) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),          2) AS Value UNION ALL
      SELECT CONVERT(DECIMAL(19, 0),          1) AS Value
   )
SELECT I.RHS               AS RightValueRaw,
       B.Value             AS ShiftValue,
       I.LHS               AS LeftValueRaw,
       (I.LHS * B.Value)   AS LeftValueShifted,
       (I.LHS * B.Value) % 4294967296 AS LeftValueShiftedLower32
FROM   Inputs AS I
       INNER JOIN Bits AS B
       ON ((FLOOR(I.RHS / B.Value) % 2) > 0);

-- RightValueRaw          :       775321 =                    10111101010010011001
-- LeftValueRaw           :      1023447 =                    11111001110111010111
-- (A Single Shift Example)
-- ShiftValue             :       524288 =                    10000000000000000000
-- LeftValueShifted       : 536580980736 = 111110011101110101110000000000000000000
-- LeftValueShiftedLower32:   4005036032 =        11101110101110000000000000000000

WITH
PartialProducts
AS (  SELECT 524288 AS ShiftValue, 536580980736 AS LeftValueShifted, 4005036032 AS LeftValueShiftedLower32 UNION ALL
      SELECT 131072 AS ShiftValue, 134145245184 AS LeftValueShifted, 1001259008 AS LeftValueShiftedLower32 UNION ALL
      SELECT  65536 AS ShiftValue,  67072622592 AS LeftValueShifted, 2648113152 AS LeftValueShiftedLower32 UNION ALL
      SELECT  32768 AS ShiftValue,  33536311296 AS LeftValueShifted, 3471540224 AS LeftValueShiftedLower32 UNION ALL
      SELECT  16384 AS ShiftValue,  16768155648 AS LeftValueShifted, 3883253760 AS LeftValueShiftedLower32 UNION ALL
      SELECT   4096 AS ShiftValue,   4192038912 AS LeftValueShifted, 4192038912 AS LeftValueShiftedLower32 UNION ALL
      SELECT   1024 AS ShiftValue,   1048009728 AS LeftValueShifted, 1048009728 AS LeftValueShiftedLower32 UNION ALL
      SELECT    128 AS ShiftValue,    131001216 AS LeftValueShifted,  131001216 AS LeftValueShiftedLower32 UNION ALL
      SELECT     16 AS ShiftValue,     16375152 AS LeftValueShifted,   16375152 AS LeftValueShiftedLower32 UNION ALL
      SELECT      8 AS ShiftValue,      8187576 AS LeftValueShifted,    8187576 AS LeftValueShiftedLower32 UNION ALL
      SELECT      1 AS ShiftValue,      1023447 AS LeftValueShifted,    1023447 AS LeftValueShiftedLower32
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
      AS ( SELECT CONVERT(DECIMAL(19, 0), (I.RHS & 2147483647) + (CASE (I.RHS & -2147483648) WHEN 0 THEN 0 ELSE 2147483648 END)) AS RHS,
                  CONVERT(DECIMAL(19, 0), (I.LHS & 2147483647) + (CASE (I.LHS & -2147483648) WHEN 0 THEN 0 ELSE 2147483648 END)) AS LHS
           FROM   ( SELECT CASE WHEN (@RightIN < @LeftIN) THEN @RightIN ELSE @LeftIN  END AS RHS,
                           CASE WHEN (@RightIN < @LeftIN) THEN @LeftIN  ELSE @RightIN END AS LHS
                  ) I
         ),
      Bits
      AS ( SELECT CONVERT(DECIMAL(19, 0), 2147483648) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0), 1073741824) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),  536870912) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),  268435456) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),  134217728) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),   67108864) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),   33554432) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),   16777216) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),    8388608) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),    4194304) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),    2097152) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),    1048576) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),     524288) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),     262144) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),     131072) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),      65536) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),      32768) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),      16384) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),       8192) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),       4096) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),       2048) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),       1024) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),        512) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),        256) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),        128) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),         64) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),         32) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),         16) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),          8) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),          4) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),          2) AS Value UNION ALL
           SELECT CONVERT(DECIMAL(19, 0),          1) AS Value
         ),
      PartialProducts
      AS ( SELECT (I.LHS * B.Value) % 4294967296 AS PartialProduct
           FROM   Inputs AS I
                  INNER JOIN Bits AS B
                  ON ((FLOOR(I.RHS / B.Value) % 2) > 0)
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
