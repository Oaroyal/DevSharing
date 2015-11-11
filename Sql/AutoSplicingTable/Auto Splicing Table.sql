CREATE TABLE #AutoSplice (
   [RowID]        INT IDENTITY(1, 1) NOT NULL PRIMARY KEY CLUSTERED,
   [CommaData]    VARCHAR(MAX)       NOT NULL,
   [Position]     INT                NOT NULL DEFAULT ( 1 ),
   [NextPosition] AS                 ( CASE CHARINDEX(',', [CommaData], [Position])
                                          WHEN 0 THEN LEN([CommaData]) + 1
                                          ELSE        CHARINDEX(',', [CommaData], [Position]) + 1
                                       END
                                     ),
   [EndOfData]    AS                 ( CASE WHEN ( [Position] > LEN([CommaData]) )
                                          THEN CONVERT(BIT, 1)
                                          ELSE CONVERT(BIT, 0)
                                       END
                                     ),
   [Item]         AS                 ( CASE WHEN ( [Position] > LEN([CommaData]) ) THEN NULL
                                            WHEN ( CHARINDEX(',', [CommaData], [Position]) = 0 ) THEN SUBSTRING([CommaData], [Position], (LEN([CommaData]) - [Position]) + 1)
                                            WHEN ( (CHARINDEX(',', [CommaData], [Position]) - [Position]) < 1 ) THEN NULL
                                            ELSE SUBSTRING([CommaData], [Position], CHARINDEX(',', [CommaData], [Position]) - [Position])
                                       END
                                     )
);

INSERT INTO #AutoSplice ( [CommaData] ) VALUES ( 'APPLE,PEAR,ORANGE,BANANA,PEACH' );
INSERT INTO #AutoSplice ( [CommaData] ) VALUES ( ',,,,' );
INSERT INTO #AutoSplice ( [CommaData] ) VALUES ( 'SQUARE,CIRCLE,TRIANGLE,ELIPSE' );
INSERT INTO #AutoSplice ( [CommaData] ) VALUES ( 'THIS,WILL,MAKE,YOUR,DAY' );

WHILE EXISTS ( SELECT TOP 1 * FROM #AutoSplice AS A WHERE A.EndOfData = 0 )
BEGIN
   UPDATE A
   SET    A.Position = A.NextPosition
   OUTPUT DELETED.RowID, ISNULL(DELETED.Item, '')
   FROM   #AutoSplice AS A
   WHERE  A.EndOfData = 0;
END;

DROP TABLE #AutoSplice;
