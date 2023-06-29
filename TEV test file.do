
use "/Users/franklin/Google Drive 2/iDisk Documents/Data & dofiles/TEV_UK_unstacked_data_mis=._'64-'05.dta", replace

gendist RLRPP1-RLRPP7, self(RLRSP) mis(diff) context(rstudyid)  
rename d_RLRPP* LRDPARTY*               

gendummies RGENDER RMARRIED || dummy:REDU RDENOM

genstacks RSYM RSYML LRDPARTY, context(rstudyid) stackid(STACKID) nocheck


for /*X in*/ new VOTE:  gen X = 0 \ replace X = 1 if STACKID==RVOTE1 \ replace X = . if RVOTE1>994
for var VOTE: gen savX = X \ replace savX = RVOTE1 if RVOTE1>994 \ replace savX = 996 if savX==999 // Code 1 if stack party was voted for; put missing code in sav versn

table RPID4 STACKID if YEAR<2005, c(m VOTE)												// Shows RIPD4 has Lab and Con reversed for EV yearts
for var RPID4: gen temp = X \replace temp = 1 if RPID4==2&YEAR<2005 \replace temp = 2 if RPID4==1&YEAR<2005 \replace RPID4 = temp \drop temp
table RPID4 STACKID if YEAR==2005, c(m VOTE)											// Not for existing British TEV data (which has a different problem)
	
for new PID: gen X = 0 \replace X = RPID2 if STACKID==RPID4 & RPID2<995 				// Set PID to strength of PID if party identified with is not missing
for var PID: gen savX = X 																// PID is zero if missing, according to TEV codebook coding procedure

table RWHICHPM STACKID if YEAR<2005, c(m VOTE)											// Shows RWHICHPM has Lab and Con reversed for EV yearts
for var RWHICHPM: gen temp = X \replace temp = 1 if RWHICHPM==2&YEAR<2005 \replace temp = 2 if RWHICHPM==1&YEAR<2005 \replace RWHICHPM = temp \drop temp
for new THISPM: gen X = 0 \ replace X = 1 if STACKID==RWHICHPM \ replace X = . if RWHICHPM>994 \ gen savX = X \ replace savX = 999 if X==.

for new PCOMP: gen X = 0  \ replace X = 1 if STACKID==RCOMP1a 						 	// Renamed measure of whether stack party/coalitn was best for MIP
for var PCOMP: gen savX = X \ replace savX = RCOMP1a if RCOMP1a>994						// RCOMP1b all missing for Britain

for new CMPSTACK: gen X = 51420 if STACKID==1 \ replace X = 51620 if STACKID==2 \ replace X = 51421 if STACKID==3  ///
      \replace X = 51902 if STACKID==4 \replace X = 51901 if STACKID==5 \replace X = 51110 if STACKID==6 \replace X = 51951 if STACKID==7

				// Following code ensures all demographics scale 0 to 1 and produces a dummy missing data indicator to accompany each, retaining max N in Y-hats
for var RGENDER RMARRIED RREGION RPUBS RSUBCL RINCOME2 ROWNHOUS: gen mX = 0 \replace mX = 1 if X==. \replace X = 0 if mX==1 // Region 1 is Scotland, yields SNP votes
for var RINCOME1: gen mX = 0 \replace mX = 1 if X==. \replace X = 0 if mX==1 						  // RINCOME1 retains values 0-3
for var RAGE: replace X = X / 100 \gen mX = 0 \replace mX = 1 if X==. \replace X = 0 if mX==1		  // Produces values 0 - 0.97 (close enough to 1)
for var REDU: replace X = X / 3	\gen mX = 0 \replace mX = 1 if X==. \replace X = 0 if mX==1			  // Produces codes 0, 0.667, 1  SHOULD BE CODED 1-3
for var RCHURCHA: replace X = (5-X)/4 if X<5 \gen mX = 0 \replace mX = 1 if X==. \replace X = 0 if mX==1 // Proxuces codes 0,1.  NEEDS TO RETAIN BACKWARD CODING
for var REGPCL3: replace X = X / 100 \gen mX = 0 \replace mX = 1 if X==. \replace X = 0 if mX==1 	  // Produces codes 0,1
for var RUNION2: replace X = 1 if X==2 \ replace X = 0 if X>2 \gen mX = 0 \replace mX = 1 if X==.	  // Runion2 has no missing data so mRUNION2 is always 0


rename dummy_* *																					  // Restore original names
genyhats RDENOM1-RDENOM4 RREGION RCHURCHA || class: RSUBCL mRSUBCL ROWNHOUS mROWNHOUS RINCOME1 mRINCOME1 REGPCL3 mREGPCL3 RUNION2 mRUNION2, depvar(VOTE) context(rstudyid) stackid(STACKID) adjust(no)		

geniimpute RSYM RSYM RSYML LRDPARTY VOTE, add(yi_RCHURCHA yi_RREGION class_VOTE) context(rstudyid) stackid(STACKID) limit(3)			// (43 seconds under old iimpute)
                                                                                                                                  // 9.5 seconds with version 2