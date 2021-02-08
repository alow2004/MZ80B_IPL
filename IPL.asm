 	  		CPU	Z80
          		ORG	0000H
		;**********************
		;
		; Personal Computer
		;	MZ-80B
		;
		;	Initial
		;	Program
		;	Loader
		;**********************
		;
0000  1804      	JR      START
		;;;;;;;;;;;;;;;;;;
		; NST RESET
		;
0002  3E03	NST:	LD      A,03H
0004  D3E3      	OUT     (0E3H),A
		;;;;;;;;;;;;;;;;;;
		: INITIALIZE
		;
0006  3E82      START:	LD      A,82H		;8255 A=OUT B=IN C=OUT
0008  D3E3      	OUT     (0E3H),A
000A  3E0F      	LD      A,0FH		;PIO A=OUT
000C  D3E9      	OUT     (0E9H),A
000E  3ECF      	LD      A,0CFH		;PIO B=IN
0010  D3EB      	OUT     (0EBH),A
0012  3EFF      	LD      A,0FFH
0014  D3EB      	OUT     (0EBH),A
0016  3E58      	LD      A,58H		;BST=1 OPEN=1 WRITE=1
0018  D3E2      	OUT     (0E2H),A
001A  3E12      	LD      A,12H
001C  D3E0      	OUT     (0E0H),A
001E  AF        	XOR     A
001F  D3F4     		OUT     (0F4H),A
0021  31E0FF    	LD      SP,0FFE0H
0024  2100D0    	LD      HL,0D000H
0027  3EB3      	LD      A,0B3H
0029  D3E8      	OUT     (0E8H),A
002B  3600      CLEAR:	LD      (HL),00H	;DISPLAY CLEAR
002D  23        	INC     HL
002E  7C        	LD      A,H
002F  B5        	OR      L
0030  20F9      	JR      NZ,CLEAR
0032  3E13      	LD      A,13H
0034  D3E8      	OUT     (0E8H),A
0036  AF        	XOR     A
0037  32ECFF    	LD      (DRIN0),A	
003A  32E6FF    	LD      (MTFG),A
003D  CD4B00    KEYIN:	CALL    KEYS1
0040  CB5F      	BIT     3,A
0042  2827      	JR      Z,CMT
0044  CB47      	BIT     0,A
0046  CAEF05    	JP      Z,EXROMT
0049  180C      	JR      NKIN
		;
004B  0614      KEYS1:	LD      B,14H		;KEY STROBE OUT
004D  DBE8      KEYS:	IN      A,(0E8H)
004F  E6F0      	AND     0F0H
0051  B0        	OR      B
0052  D3E8      	OUT     (0E8H),A
0054  DBEA      	IN      A,(0EAH)
0056  C9        	RET     
		;
		;
0057  CD5F00    NKIN:	CALL    FDCC
005A  CA3C03    	JP      Z,FD
005D  180C      	JR      CMT
		;
005F  3EA5      FDCC:	LD      A,0A5H		;CHECK IF FLOPPY CONTROLLER PRESENT
0061  47        	LD      B,A
0062  D3D9      	OUT     (0D9H),A		;LOAD TRACK REGISTER WITH 0A5H
0064  CDD605    	CALL    DLY80U			;INSERT SOME WAIT TIME
0067  DBD9      	IN      A,(0D9H)        ;READ TRACK REGISTER
0069  B8        	CP      B				;COMPARE TRACK REGISTER VALUE WITH 0A5H
006A  C9        	RET     
		;;;;;;;;;;;;;;;;;
		;               ;
		;  CMT CONTROL  ;
		;               ;
		;;;;;;;;;;;;;;;;;
006B  CDB501    CMT:	CALL    MSTOP
006E  CD1D02    	CALL    DEL6
0071  CDCE01    	CALL    KYEMES
0074  CDAE00    	CALL    ?RDI
0077  3817      	JR      C,ST1
0079  CD3002    	CALL    LDMSG
007C  2101CF    	LD      HL,NAME
007F  1E10      	LD      E,10H
0081  0E10      	LD      C,10H
0083  CD3902    	CALL    DISP2
0086  3A00CF    	LD      A,(ATRB)
0089  FE01      	CP      01H
008B  2011      	JR      NZ,MISMCH
008D  CDCF00    	CALL    ?RDD
0090  F5        ST1:	PUSH    AF
0091  CD1D02    	CALL    DEL6
0094  CD0B02    	CALL    REW
0097  F1        	POP     AF
0098  DA5F05    	JP      C,TRYAG
009B  C30200    	JP      NST
		;
009E  212603    MISMCH:	LD      HL,MES16
00A1  1E0A      	LD      E,0AH
00A3  0E0F      	LD      C,0FH
00A5  CD4602    	CALL    DISP
00A8  CDB501    	CALL    MSTOP
00AB  37        	SCF     
00AC  18E2      	JR      ST1
		;
		;READ INFORMATION
		;      CF=1:ERROR
		RDINF:
00AE  F3        ?RDI:	DI      
00AF  1604      	LD      D,04H
00B1  018000    	LD      BC,0080H
00B4  2100CF    	LD      HL,IBUFE
00B7  CD8601    RD1:	CALL    MOTOR
00BA  380E      	JR      C,STPEIR
00BC  CD5201    	CALL    TMARK
00BF  3809      	JR      C,STPEIR
00C1  CDDB00    	CALL    RTAPE
00C4  3804      	JR      C,STPEIR
00C6  CB5A      RET2S:	BIT     3,D
00C8  2803      	JR      Z,EIRTN
00CA  CDB501    STPEIR:	CALL    MSTOP
00CD  FB        EIRTN:	EI      
00CE  C9        	RET     
		;
		;
		;READ DATA
		RDDAT:
00CF  F3        ?RDD:	DI      
00D0  1608      	LD      D,08H
00D2  ED4B12CF  	LD      BC,(SIZE)
00D6  210080    	LD      HL,8000H
00D9  18DC      	JR      RD1
		;
		;
		;READ TAPE
		;      BC=SIZE
		;      DE=LOAD ADDRSS
00DB  D5        RTAPE:	PUSH    DE
00DC  C5        	PUSH    BC
00DD  E5        	PUSH    HL
00DE  2602      	LD      H,02H
00E0  CD7A01    RTP2:	CALL    SPDIN
00E3  3838      	JR      C,TRTN1		;BREAK
00E5  28F9      	JR      Z,RTP2
00E7  54        	LD      D,H
00E8  210000    	LD      HL,0000H
00EB  22E0FF    	LD      (SUMDT),HL
00EE  E1        	POP     HL
00EF  C1        	POP     BC
00F0  C5        	PUSH    BC
00F1  E5        	PUSH    HL
00F2  CD3201    RTP3:	CALL    RBYTE
00F5  3826      	JR      C,TRTN1
00F7  77        	LD      (HL),A
00F8  23        	INC     HL
00F9  0B        	DEC     BC
00FA  78        	LD      A,B
00FB  B1        	OR      C
00FC  20F4      	JR      NZ,RTP3
00FE  2AE0FF    	LD      HL,(SUMDT)
0101  CD3201    	CALL    RBYTE
0104  3817      	JR      C,TRTN1
0106  5F        	LD      E,A
0107  CD3201    	CALL    RBYTE
010A  3811      	JR      C,TRTN1
010C  BD        	CP      L
010D  2004      	JR      NZ,RTP5
010F  7B        	LD      A,E
0110  BC        	CP      H
0111  280A      	JR      Z,TRTN1
0113  15        RTP5:	DEC     D
0114  2803      	JR      Z,RTP6
0116  62        	LD      H,D
0117  18C7      	JR      RTP2
0119  CD3F02    RTP6:	CALL    BOOTER
011C  37        	SCF     
011D  E1        	POP     HL
011E  C1        	POP     BC
011F  D1        	POP     DE
0120  C9        	RET     
		;EDGE
0121  DBE1      EDGE:	IN      A,(0E1H)
0123  2F        	CPL     
0124  07        	RLCA    
0125  D8        	RET     C		;BREAK
0126  07        	RLCA    
0127  30F8      	JR      NC,EDGE		;WAIT ON LOW
0129  DBE1      EDGE1:	IN      A,(0E1H)
012B  2F        	CPL     
012C  07        	RLCA    
012D  D8        	RET     C		;BREAK
012E  07        	RLCA    
012F  38F8      	JR      C,EDGE1		;WAIT ON HIGH
0131  C9        	RET     
		; 1 BYTE READ
		;      DATA=A
		;      SUMDT STORE
0132  E5        RBYTE:	PUSH    HL
0133  210008    	LD      HL,0800H	; 8 BITS
0136  CD7A01    RBY1:	CALL    SPDIN
0139  3815      	JR      C,RBY3		;BREAK
013B  280A      	JR      Z,RBY2		;BIT=0
013D  E5        	PUSH    HL
013E  2AE0FF    	LD      HL,(SUMDT)	;CHECKSUM
0141  23        	INC     HL
0142  22E0FF    	LD      (SUMDT),HL
0145  E1        	POP     HL
0146  37        	SCF     
0147  CB15      RBY2:	RL      L
0149  25        	DEC     H
014A  20EA      	JR      NZ,RBY1
014C  CD2101    	CALL    EDGE
014F  7D        	LD      A,L
0150  E1        RBY3:	POP     HL
0151  C9        	RET     
		;TAPE MARK DETECT
		;      E=L:INFORMATION
		;      E=S:DATA
0152  E5        TMARK:	PUSH    HL
0153  211414    	LD      HL,1414H
0156  CB5A      	BIT     3,D
0158  2001      	JR      NZ,TM0
015A  29        	ADD     HL,HL
015B  22E2FF    TM0:	LD      (TMCNT),HL
015E  2AE2FF    TM1:	LD      HL,(TMCNT)
0161  CD7A01    TM2:	CALL    SPDIN
0164  38EA      	JR      C,RBY3
0166  28F6      	JR      Z,TM1
0168  25        	DEC     H
0169  20F6      	JR      NZ,TM2
016B  CD7A01    TM3:	CALL    SPDIN
016E  38E0      	JR      C,RBY3
0170  20EC      	JR      NZ,TM1
0172  2D        	DEC     L
0173  20F6      	JR      NZ,TM3
0175  CD2101    	CALL    EDGE
0178  18D6      	JR      RBY3
		;READ 1 BIT
017A  CD2101    SPDIN:	CALL    EDGE		;WAIT ON HIGH
017D  D8        	RET     C		;BREAK

017E  CD2902    	CALL    DLY2
0181  DBE1      	IN      A,(0E1H)	;READ BIT
0183  E640      	AND     40H
0185  C9        	RET     
		;
		;
		;MOTOR ON
0186  D5        MOTOR:	PUSH    DE
0187  C5        	PUSH    BC
0188  E5        	PUSH    HL
0189  DBE1      	IN      A,(0E1H)
018B  E620      	AND     20H
018D  281F      	JR      Z,MOTRD
018F  218B02    	LD      HL,MES6
0192  1E0A      	LD      E,0AH
0194  0E0E      	LD      C,0EH
0196  CD4602    	CALL    DISP
0199  CDC201    	CALL    OPEN
019C  DBEA      MOT1:	IN      A,(0EAH)
019E  2F        	CPL     
019F  07        	RLCA    
01A0  380F      	JR      C,MOTR
01A2  DBE1      	IN      A,(0E1H)
01A4  E620      	AND     20H
01A6  20F4      	JR      NZ,MOT1
01A8  CDCE01    	CALL    KYEMES
01AB  CD2302    	CALL    DEL1M
01AE  CDD901    MOTRD:	CALL    PLAY
01B1  E1        MOTR:	POP     HL
01B2  C1        	POP     BC
01B3  D1        	POP     DE
01B4  C9        	RET     
		;
		;
		;MOTOR STOP
01B5  3E0D      MSTOP:	LD      A,0DH
01B7  D3E3      	OUT     (0E3H),A	;READ MODE
01B9  3E1A      	LD      A,1AH
01BB  D3E0      	OUT     (0E0H),A
01BD  CD1D02    	CALL    DEL6
01C0  182D      	JR      BLK3
		;EJECT
01C2  3E08      OPEN:	LD      A,08H
01C4  D3E3      	OUT     (0E3H),A
01C6  CD1D02    	CALL    DEL6
01C9  3E09      	LD      A,09H
01CB  D3E3      	OUT     (0E3H),A
01CD  C9        	RET     
		;
		;
01CE  216F02    KYEMES:	LD      HL,MES3
01D1  1E04      	LD      E,04H
01D3  0E1C      	LD      C,1CH
01D5  CD4602    	CALL    DISP
01D8  C9        	RET     
		;
		;PLAY
01D9  CDF401    PLAY:	CALL    FR
01DC  CD1D02    	CALL    DEL6
01DF  3E16      	LD      A,16H
01E1  D3E0      	OUT     (0E0H),A
01E3  180A      	JR      BLK3
01E5  CD1D02    BLK1:	CALL    DEL6
01E8  CDEF01    	CALL    BLK3
01EB  3E13      	LD      A,13H
01ED  D3E0      BLK2:	OUT     (0E0H),A
01EF  3E12      BLK3:	LD      A,12H
01F1  D3E0      	OUT     (0E0H),A
01F3  C9        	RET     
		;
		;
01F4  3E12      FR:	LD      A,12H
01F6  D3E0      FR1:	OUT     (0E0H),A
01F8  CD1D02    	CALL    DEL6
01FB  3E0B      	LD      A,0BH
01FD  D3E3      	OUT     (0E3H),A
01FF  CD1D02    	CALL    DEL6
0202  3E0A      	LD      A,0AH
0204  D3E3      	OUT     (0E3H),A
0206  C9        	RET     

0207  3E10      RR:	LD      A,10H
0209  18EB      	JR      FR1
		;REWIND
020B  CD0702    REW:	CALL    RR
020E  18D5      	JR      BLK1
		;
		;TIMING DEL
0210  F5        D1M:	PUSH    AF
0211  AF        L0211:	XOR     A
0212  3D        L0212:	DEC     A
0213  20FD      	JR      NZ,L0212
0215  0B        	DEC     BC
0216  78        	LD      A,B
0217  B1        	OR      C
0218  20F7      	JR      NZ,L0211
021A  F1        	POP     AF
021B  C1        	POP     BC
021C  C9        	RET     

021D  C5        DEL6:	PUSH    BC
021E  01E900    	LD      BC,00E9H	;233D
0221  18ED      	JR      DM1
0223  C5        DEL1M:	PUSH    BC
0224  010F06    	LD      BC,060FH	;1551D
0227  18E7      	JR      D1M
		;
		;TAPE DELAY TIMING
		;
		;
0229  3E31      DLY2:	LD      A,31H
022B  3D        L022B:	DEC     A
022C  C22B02    	JP      NZ,L022B
022F  C9        	RET     
		;
		;
		;
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		IBUFE:	EQU	0CF00H
		ATRB:	EQU	0CF00H
		NAME:	EQU	0CF01H
		SIZE:	EQU	0CF12H
		DTADR:	EQU	0CF14H
		SUMDT:	EQU	0FFE0H
		TMCNT:	EQU	0FFE2H
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;
0230  216102    LDMSG:	LD      HL,MES1
0233  1E00      	LD      E,00H
0235  0E0E      	LD      C,0EH
0237  180D      	JR      DISP
		;
0239  3E93      DISP2:	LD      A,93H
023B  D3E8      	OUT     (0E8H),A
023D  1817      	JR      DISP1
		;
023F  219902    BOOTER:	LD      HL,MES8
0242  1E0A      	LD      E,0AH
0244  0E0D      	LD      C,0DH
		;
0246  3E93      DISP:	LD      A,93H
0248  D3E8      	OUT     (0E8H),A
024A  D9        	EXX     
024B  2100D0    	LD      HL,0D000H
024E  3600      DISP3:	LD      (HL),00H
0250  23        	INC     HL
0251  7C        	LD      A,H
0252  B5        	OR      L
0253  20F9      	JR      NZ,DISP3
0255  D9        	EXX     
0256  AF        DISP1:	XOR     A
0257  47        	LD      B,A
0258  16D0      	LD      D,D0H
025A  EDB0      	LDIR    
025C  3E13      	LD      A,13H
025E  D3E8      	OUT     (0E8H),A
0260  C9        	RET     
		;
		;
0261  49        MES1:	DB	"IPL is loading"
026F  49        MES3:	DB	"IPL is looking for a program"
028B  4D        MES6:	DB	"Make ready CMT"
0299  4C        MES8:	DB	"Loading error"
02A6  4D        MES9:	DB	"Make ready FD"
02B3  50        MES10:	DB	"Press F or C"
02BF  46        MES11:	DB	"F:Floppy diskette"
02D0  43        MES12:	DB	"C:Cassette tape"
02DF  44        MES13:	DB	"Drive No? (1-4)"
02EE  54        MES14:	DB	"This diskette is not master"
0309  50        MES15:	DB	"Pressing S key starts the CMT"
0326  46        MES16:	DB	"File mode error"
		;
0335  014950    IPLMC:	DB	01H
0336  			DB	"IPLPRO"
		;
		;
		;
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;                          ;
		;  MFM MINIFLOPPY CONTROL  ;
		;                          ;
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;
		;  CASE OF DISK INITIALIZE
		;     DRIVE NO=DRINO (0-3)
		;
		;  CASE OF SEQUENTIAL READ
		;     DRIVE NO=DRINO (0-3)
		;     BYTE SIZE     =IY+2,3
		;     ADDRESS       =IX+0,1
		;     NEXT TRACK    =IY+0
		;     NEXT SECTOR   =IY+1
		;     START TRACK   =IY+4
		;     START SECTOR  =IY+5
		;
		;
		; I/O PORT ADDRESS
		;
		CR:	EQU	0D8H		;STATUS/COMMAND PORT
		TR:	EQU	0D9H		;TRACK REG PORT
		SCR:	EQU	0DAH		;SECTOR REG PORT
		DR:	EQU	0DBH		;DATA REG PORT
		DM:	EQU	0DCH		;MOTOR/DRIVE PORT
		HS:	EQU	0DDH		;HEAD SIDE SELECT PORT
		;
		;;;;;;;;;;
		;FD
033C  DD2100CF  FD:	LD      IX,IBADR1
0340  AF        	XOR     A
0341  321ECF    	LD      (0CF1EH),A
0344  321FCF    	LD      (0CF1FH),A
0347  FD21E0FF  	LD      IY,0FFE0H
034B  210001    	LD      HL,0100H
034E  FD7502    	LD      (IY+2),L
0351  FD7403    	LD      (IY+3),H
0354  CD7A04    	CALL    BREAD		;INFORMATION INPUT
0357  2100CF    	LD      HL,0CF00H	;MASTER CHECK
035A  113503    	LD      DE,IPLMC
035D  0606      	LD      B,06H
035F  4E        MCHECK:	LD      C,(HL)
0360  1A        	LD      A,(DE)
0361  B9        	CP      C
0362  C24A05    	JP      NZ,NMASTE
0365  23        	INC     HL
0366  13        	INC     DE
0367  10F6      	DJNZ    MCHECK
0369  CD3002    	CALL    LDMSG
036C  2107CF    	LD      HL,0CF07H
036F  1E10      	LD      E,10H
0371  0E0A      	LD      C,0AH
0373  CD3902    	CALL    DISP2
0376  DD210080  	LD      IX,IBADR2
037A  2A14CF    	LD      HL,(0CF14H)
037D  FD7502    	LD      (IY+2),L
0380  FD7403    	LD      (IY+3),H
0383  CD7A04    	CALL    BREAD
0386  CDF303    	CALL    MOFF
0389  C30200    	JP      NST
		;
		;
038C  21A602    NODISK:	LD      HL,MES9
038F  1E0A      	LD      E,0AH
0391  0E0D      	LD      C,0DH
0393  CD4602    	CALL    DISP
0396  C35905    	JP      ERROR1
		;
		; READY CHECK
		;
0399  3AE6FF    READY:	LD      A,(MTFG)
039C  0F        	RRCA    
039D  D4CC03    	CALL    NC,MTON
03A0  3AECFF    	LD      A,(DRINO)	;DRIVE NO GET
03A3  F684      	OR      84H
03A5  D3DC      	OUT     (DM),A		;DRIVE SELECT MOTON
03A7  AF        	XOR     A
03A8  CDE405    	CALL    DLY60M
03AB  210000    	LD      HL,0000H
03AE  2B        REDY0:	DEC     HL
03AF  7C        	LD      A,H
03B0  B5        	OR      L
03B1  28D9      	JR      Z,NODISK
03B3  DBD8      	IN      A,(CR)		;STATUS GET
03B5  2F        	CPL     
03B6  07        	RLCA    
03B7  38F5      	JR      C,REDY0
03B9  3AECFF    	LD      A,(DRINO)
03BC  4F        	LD      C,A
03BD  21E7FF    	LD      HL,CLBF0
03C0  0600      	LD      B,00H
03C2  09        	ADD     HL,BC
03C3  CB46      	BIT     0,(HL)
03C5  C0        	RET     NZ
03C6  CD0904    	CALL    RCLB
03C9  CBC6      	SET     0,(HL)
03CB  C9        	RET     
		;
		; MOTOR ON
		;
03CC  3E80      MTON:	LD      A,80H
03CE  D3DC      	OUT     (DM),A
03D0  060A      	LD      B,0AH		;1SEC DELAY
03D2  21193C    MTD1:	LD      HL,3C19H
03D5  2B        MTD2:	DEC     HL
03D6  7D        	LD      A,L
03D7  B4        	OR      H
03D8  20FB      	JR      NZ,MTD2
03DA  10F6      	DJNZ    MTD1
03DC  3E01      	LD      A,01H
03DE  32E6FF    	LD      (MTFG),A
03E1  C9        	RET     
		;
		;SEEK TREATMENT
		;
03E2  3E1B      SEEK:	LD      A,1BH
03E4  2F        	CPL     
03E5  D3D8      	OUT     (CR),A
03E7  CD2104    	CALL    BUSY
03EA  CDE405    	CALL    DLY60M
03ED  DBD8      	IN      A,(CR)
03EF  2F        	CPL     
03F0  E699      	AND     99H
03F2  C9        	RET     
		;
		;MOTOR OFF
		;
03F3  CDDD05    MOFF:	CALL    DLY1M
03F6  AF        	XOR     A
03F7  D3DC      	OUT     (DM),A
03F9  32E7FF    	LD      (CLBF0),A
03FC  32E8FF    	LD      (CLBF1),A
03FF  32E9FF    	LD      (CLBF2),A
0402  32EAFF    	LD      (CLBF3),A
0405  32E6FF    	LD      (MTFG),A
0408  C9        	RET     
		;
		;RECALIBRATION
		;
0409  E5        RCLB:	PUSH    HL
040A  3E0B      	LD      A,0BH
040C  2F        	CPL     
040D  D3D8      	OUT     (CR),A
040F  CD2104    	CALL    BUSY
0412  CDE405    	CALL    DLY60M
0415  DBD8      	IN      A,(CR)
0417  2F        	CPL     
0418  E685      	AND     85H
041A  EE04      	XOR     04H
041C  E1        	POP     HL
041D  C8        	RET     Z
041E  C35605    	JP      ERROR
		;
		;BUSY AND WAIT
		;
0421  D5        BUSY:	PUSH    DE
0422  E5        	PUSH    HL
0423  CDD605    	CALL    DLY80U
0426  1E07      	LD      E,07H
0428  210000    BUSY2:	LD      HL,0000H
042B  2B        BUSY0:	DEC     HL
042C  7C        	LD      A,H
042D  B5        	OR      L
042E  2809      	JR      Z,BUSY1
0430  DBD8      	IN      A,(CR)
0432  2F        	CPL     
0433  0F        	RRCA    
0434  38F5      	JR      C,BUSY0
0436  E1        	POP     HL
0437  D1        	POP     DE
0438  C9        	RET
			;
0439  1D        BUSY1:	DEC     E
043A  20EC      	JR      NZ,BUSY2
043C  C35605    	JP      ERROR
		;
		;DATA CHECK
		;
043F  0600      CONVRT:	LD      B,00H
0441  111000    	LD      DE,0010H
0444  2A1ECF    	LD      HL,(0CF1EH)
0447  AF        	XOR     A
0448  ED52      TRANS:	SBC     HL,DE
044A  3803      	JR      C,TRANS1
044C  04        	INC     B
044D  18F9      	JR      TRANS
044F  19        TRANS1:	ADD     HL,DE
0450  60        	LD      H,B
0451  2C        	INC     L
0452  FD7404    	LD      (IY+4),H
0455  FD7505    	LD      (IY+5),L
0458  3AECFF    DCHK:	LD      A,(DRINO)
045B  FE04      	CP      04H
045D  3018      	JR      NC,DTCK1
045F  FD7E04    	LD      A,(IY+4)
0462  FE46      	CP      46H		;70D
0464  3011      	JR      NC,DTCK1
0466  FD7E05    	LD      A,(IY+5)
0469  B7        	OR      A
046A  280B      	JR      Z,DTCK1
046C  FE11      	CP      11H		;17D
046E  3007      	JR      NC,DTCK1
0470  FD7E02    	LD      A,(IY+2)
0473  FDB603    	OR      (IY+3)
0476  C0        	RET     NZ
0477  C35605    DTCK1:	JP      ERROR
		;
		;SEQUENTIAL READ
		;
047A  F3        BREAD:	DI      
047B  CD3F04    	CALL    CONVRT
047E  3E0A      	LD      A,0AH
0480  32EBFF    	LD      (RETRY),A
0483  CD9903    READ1:	CALL    READY
0486  FD5603    	LD      D,(IY+3)
0489  FD7E02    	LD      A,(IY+2)
048C  B7        	OR      A
048D  2801      	JR      Z,RE0
048F  14        	INC     D
0490  FD7E05    RE0:	LD      A,(IY+5)
0493  FD7701    	LD      (IY+1),A
0496  FD7E04    	LD      A,(IY+4)
0499  FD7700    	LD      (IY+0),A
049C  DDE5      	PUSH    IX
049E  E1        	POP     HL
049F  CB3F      RE8:	SRL     A
04A1  2F        	CPL     
04A2  D3DB      	OUT     (DR),A
04A4  3004      	JR      NC,RE1
04A6  3E01      	LD      A,01H
04A8  1802      	JR      RE2
04AA  3E00      RE1:	LD      A,00H
04AC  2F        RE2:	CPL     
04AD  D3DD      	OUT     (HS),A
04AF  CDE203    	CALL    SEEK
04B2  206A      	JR      NZ,REE
04B4  0EDB      	LD      C,0DBH
04B6  FD7E00    	LD      A,(IY+0)
04B9  CB3F      	SRL     A
04BB  2F        	CPL     
04BC  D3D9      	OUT     (TR),A
04BE  FD7E01    	LD      A,(IY+1)
04C1  2F        	CPL     
04C2  D3DA      	OUT     (SCR),A
04C4  D9        	EXX     
04C5  21F704    	LD      HL,RE3
04C8  E5        	PUSH    HL
04C9  D9        	EXX     
04CA  3E94      	LD      A,94H
04CC  2F        	CPL     
04CD  D3D8      	OUT     (CR),A
04CF  CD2D05    	CALL    WAIT
04D2  0600      RE6:	LD      B,H00
04D4  DBD8      RE4:	IN      A,(CR)
04D6  0F        	RRCA    
04D7  D8        	RET     C
04D8  0F        	RRCA    
04D9  38F9      	JR      C,RE4
04DB  EDA2      	INI     
04DD  20F5      	JR      NZ,RE4
04DF  FD3401    	INC     (IY+1)
04E2  FD7E01    	LD      A,(IY+1)
04E5  FE11      	CP      11H		;17D
04E7  2805      	JR      Z,RETS
04E9  15        	DEC     D
04EA  20E6      	JR      NZ,RE6
04EC  1801      	JR      RE5
04EE  15        RETS:	DEC     D
04EF  3ED8      RE5:	LD      A,0D8H		;FORCE INTERRUPT
04F1  2F        	CPL     
04F2  D3D8      	OUT     (CR),A
04F4  CD2104    	CALL    BUSY
04F7  DBD8      RE3:	IN      A,(CR)
04F9  2F        	CPL     
04FA  E6FF      	AND     0FFH
04FC  2020      	JR      NZ,REE
04FE  D9        	EXX     
04FF  E1        	POP     HL
0500  D9        	EXX     
0501  FD7E01    	LD      A,(IY+1)
0504  FE11      	CP      11H		;17D
0506  2008      	JR      NZ,REX
0508  3E01      	LD      A,01H
050A  FD7701    	LD      (IY+1),A
050D  FD3400    	INC     (IY+0)
0510  7A        REX:	LD      A,D
0511  B7        	OR      A
0512  2005      	JR      NZ,RE7
0514  3E80      	LD      A,80H
0516  D3DC      	OUT     (DM),A
0518  C9        	RET     
0519  FD7E00    RE7:	LD      A,(IY+0)
051C  1881      	JR      RE8
051E  3AEBFF    REE:	LD      A,(RETRY)
0521  3D        	DEC     A
0522  32EBFF    	LD      (RETRY),A
0525  282F      	JR      Z,ERROR
0527  CD0904    	CALL    RCLB
052A  C38304    	JP      RED1
		;
		; WAIT AND BUSY OFF
		;
052D  D5        WAT:	PUSH    DE
052E  E5        	PUSH    HL
052F  CDD605    	CALL    DLY80U
0532  1E08      	LD      E,08H
0534  210000    WAIT2:	LD      HL,0000H
0537  2B        WAIT0:	DEC     HL
0538  7C        	LD      A,H
0539  B5        	OR      L
053A  2809      	JR      Z,WAIT1
053C  DBD8      	IN      A,(CR)
053E  2F        	CPL     
053F  0F        	RRCA    
0540  30F5      	JR      NC,WAIT0
0542  E1        	POP     HL
0543  D1        	POP     DE
0544  C9        	RET     
0545  1D        WAIT1:	DEC     E
0546  20EC      	JR      NZ,WAIT2
0548  180C      	JR      ERROR
		;
054A  21EE02    NMASTE:	LD      HL,MES14
054D  1E07      	LD      E,07H
054F  0E1B      	LD      C,1BH		;27D
0551  CD4602    	CALL    DISP
0554  1803      	JR      ERROR1
		;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;                         ;
		;   ERRROR OR BREAK       ;
		;                         ;
		;;;;;;;;;;;;;;;;;;;;;;;;;;;
0556  CD3F02    ERROR:	CALL    BOOTER
0559  CDF303    ERROR1:	CALL    MOFF
055C  31E0FF    TRYAG2:	LD      SP,0FFE0H
		;
		;TRYAG
		;
055F  CD5F00    TRYAG:	CALL    FDCC
0562  2047      	JR      NZ,TRYAG3
0564  21B302    	LD      HL,MES10
0567  1E5A      	LD      E,5AH
0569  0E0C      	LD      C,0CH		;12D
056B  CD3902    	CALL    DISP2
056E  1EAB      	LD      E,0ABH
0570  0E11      	LD      C,11H		;17D
0572  CD3902    	CALL    DISP2
0575  1ED3      	LD      E,0D3H
0577  0E0F      	LD      C,0FH		;15D
0579  CD3902    	CALL    DISP2
057C  CD4B00    TRYAG1:	CALL    KEYS1
057F  CB5F      	BIT     3,A
0581  CA6B00    	JP      Z,CMT
0584  CB77      	BIT     6,A
0586  2802      	JR      Z,DNO
0588  18F2      	JR      TRYAG1
058A  21DF02    DNO:	LD      HL,MES13	;DRIVE NO SELECT
058D  1E0A      	LD      E,0AH
058F  0E0F      	LD      C,0FH
0591  CD4602    	CALL    DISP
0594  1612      DNO10:	LD      D,12H
0596  CDC105    	CALL    DNO0
0599  3009      	JR      NC,DNO3
059B  1618      	LD      D,18H
059D  CDC105    	CALL    DNO0
05A0  3002      	JR      NC,DNO3
05A2  18F0      	JR      DNO10
05A4  78        DNO3:	LD      A,B
05A5  32ECFF    	LD      (DRINO),A
05A8  C33C03    	JP      FD
		;
05AB  210903    TRYAG3:	LD      HL,MES15
05AE  1E54      	LD      E,54H
05B0  0E1D      	LD      C,1DH		;29D
05B2  CD3902    	CALL    DISP2
05B5  0606      TRYAG4:	LD      B,06H
05B7  CD4D00    TRYAG5:	CALL    KEYS
05BA  CB5F      	BIT     3,A
05BC  CA6B00    	JP      Z,CMT
05BF  18F6      	JR      TRYAG5
		;
05C1  DBE8      DNO0:	IN      A,(0E8H)
05C3  E6F0      	AND     0F0H
05C5  B2        	OR      D
05C6  D3E8      	OUT     (0E8H),A
05C8  DBEA      	IN      A,(0EAH)
05CA  0600      	LD      B,00H
05CC  0E04      	LD      C,04H
05CE  0F        	RRCA    
05CF  0F        DNO1:	RRCA    
05D0  D0        	RET     NC
05D1  04        	INC     B
05D2  0D        	DEC     C
05D3  20FA      	JR      NZ,DNO1
05D5  C9        	RET     
		;
		;  TIME DELAY (1M &60M &80U )
		;
05D6  D5        DLY80U:	PUSH    DE
05D7  110D00    	LD      DE,000DH	;13D
05DA  C3E805    	JP      DYT
05DD  D5        DLY1M:	PUSH    DE
05DE  118200    	LD      DE,0082H	;130D
05E1  C3E805    	JP      DLYT
05E4  D5        DLY60M:	PUSH    DE
05E5  112C1A    	LD      DE,1A2CH	;6700D
05E8  1B        DLYT:	DEC     DE
05E9  7B        	LD      A,E
05EA  B2        	OR      D
05EB  20FB      	JR      NZ,DLYT
05ED  D1        	POP     DE
05EE  C9        	RET     
		;
		;;;;;;;;;;;;;;;;;;;;;;;;;
		;INPUT BUFFER ADDRESS
		;
		IBADR1:	EQU	0CF00H
		IBADR2:	EQU	8000H
		;
		;   SUBROUTINE WORK
		;
		NTRACK:	EQU	0FFE0H
		NSECT:	EQU	0FFE1H
		BSIZE:	EQU	0FFE2H
		STTR:	EQU	0FFE4H
		STSE:	EQU	0FFE5H
		MTFG:	EQU	0FFE6H
		CLBF0:	EQU	0FFE7H
		CLBF1:	EQU	0FFE8H
		CLBF2:	EQU	0FFE9H
		CLBF3:	EQU	0FFEAH
		RETRY:	EQU	0FFEBH
		DRINO:	EQU	0FFECH
		;
		;;;;;;;;;;;;;;;;;;;;;;;
		;                     ;
		;   INTRAM EXROM      ;
		;                     ;
		;;;;;;;;;;;;;;;;;;;;;;;
05EF  210080    EXROMT:	LD      HL,8000H
05F2  DD21F805  	LD      IX,EROM1
05F6  181A      	JR      SEROMA
05F8  DBF9      EROM1:	IN      A,(0F9H)
05FA  FE00      	CP      00H
05FC  C25700    	JP      NZ,NKIN
05FF  DD210506  	LD      IX,EROM2
0603  180D      ERMT1:	JR      SEROMA
0605  DBF9      EROM2:	IN      A,(0F9H)
0607  77        	LD      (HL),A
0608  23        	INC     HL
0609  7D        	LD      A,L
060A  B4        	OR      H
060B  20F6      	JR      NZ,EROMT1
060D  D3F8      	OUT     (0F8H),A
060F  C30200    	JP      NST
		;
0612  7C        SEROMA:	LD      A,H
0613  D3F8      	OUT     (0F8H),A
0615  7D        	LD      A,L
0616  D3F9      	OUT     (0F9H),A
0618  1604      	LD      D,04H
061A  15        SEROMD:	DEC     D
061B  20FD      	JR      NZ,SEROMD
061D  DDE9      	JP      (IX)
