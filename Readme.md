Project started: Mon Dec 22 10:07:38 MST 2014



## Update February 20, 2016


<em>From: Stephanie Hansen [mailto:shansen@bslw.com] 
Sent: February-19-16 12:30 PM
To: Shona Dippie; ILS Admins
Cc: Stephanie Hansen
Subject: Edmonton Public Library (CNEDM) - February Authority Notification & Current Cataloging

We have completed your MARS Authority Notification and Current Cataloging Services. Your output files are ready to be picked up on our FTP site. Clicking on the links below will automatically begin the download process.
Note: This month we’ve added a custom step that allows us to export any authorities that were added during the update process that have a date newer than the date in the record you sent us (example: the Mickey Mouse record you pointed out a couple weeks ago). The records that are exported are split by usage (name and subject), but each file contains the same records. When we add authorities, we add the usages that are set within those records, and in most cases those are both name and subject, so they will export into both files. If you have any questions, just let me know. You’ll start seeing these files every month now.

[I have changed the order from the original email to show the correct ordering according to BSLW]

Notification (load first):
DEL.MRC - 20 records
NAME.CHG.mrc - 1,669 records
NAME.NEW.mrc - 274 records
SERIES.CHG.mrc - 26 records
SUBJ.CHG.mrc - 1,357 records
SUBJ.NEW.mrc - 9 records
TITLE.CHG.mrc - 38 records
TITLE.NEW.mrc - 2 records


Current Cataloging (load second):
BIB.MRC - 5,173 records
GENRE.NEW.mrc - 63 records
NAME.NEW.mrc - 1,003 records
SUBJ.NEW.mrc - 278 records
TITLE.NEW.mrc - 21 records

Updates:
LC.GENRE.mrc - 2 records
NAME.NEW.mrc - 94 records
SUBJ.NEW.mrc - 94 records
TITLE.NEW.mrc - 1 records
</em>

# Project Notes

## Instructions for Running:
Validate an incoming or outgoing flat files `-v` shows all warnings (use "update" to not show failed matches on new
records). '`-o`' will output all changes. Unmatched authority IDs will be output untouched, but matching authority IDs 
are output as normalized, so they can match the normalized IDs in Symphony. In this one step you will get flat output
that you can update on match and create on no match (see authload -x) and match success rate. Match points for Authorities
are always considered to be 001, while match point for bib records are the TCN (in the 035 tag).
```bash
cat 20150107_EPL_Authority_Records.flat | ./authority.pl -v"all" -o >fixed20150107.flat
```
 
During operation the script will create a dump of authority keys and authority IDs which it will attempt to match the
authority records passed in on STDIN. With no switches it will report the match rate and some other interesting 
stats. If you want a loadable file just use the -o to output to STDOUT.

# Product Description:
This script validates flat authority marc files.
Perl script written by Andrew Nisbet for Edmonton Public Library, distributable by the enclosed license.

# Repository Information:
This product is under version control using Git.

# Dependencies:
None

# Known Issues:
The investigations are as follows.
I cannot find any connection between the authorities that were loaded and those the authority ids we have in the system.
Let us break the problem down by focusing on a NAME authority returned from BSLW:
```bash
$ grep "Leonard Williams" *.flat
ALLAUTHORITIES.flat:.100. 1 |aLevy, Leonard Williams,|d1923-
ALLAUTHORITIES.flat:.400. 1 |wna|aLevy, Leonard W.|q(Leonard Williams),|d1923-
BIB.flat:.100. 1 |aLevy, Leonard Williams,|d1923-
NAME.flat:.100. 1 |aLevy, Leonard Williams,|d1923-
NAME.flat:.400. 1 |wna|aLevy, Leonard W.|q(Leonard Williams),|d1923-
```


== snip ==
```bash
*** DOCUMENT BOUNDARY ***
FORM=PERSONAL
.000. |az n 0n
.001. |a000000193160
.003. |aCaOOAMICUS
.005. |a20091210235959
.008. |a200912nxbacnnnaabn           a aaa     |
.040.   |aCaOOP|bnnn|cCaOOP
.100. 1 |aLevy, Leonard Williams,|d1923-
.400. 1 |wna|aLevy, Leonard W.|q(Leonard Williams),|d1923-
.670.   |aHis  Emergence of a free press.
.670.   |aLCNA 1977-1984.
*** DOCUMENT BOUNDARY ***
...
```
== snip ==  

or from marc edit:

== snip ==  
```bash
=LDR  00380nz   2200133n  4500
=001  000000193160
=003  CaOOAMICUS
=005  20091210235959
=008  200912nxbacnnnaabn\\\\\\\\\\\a\aaa\\\\\|
=040  \\$aCaOOP$bnnn$cCaOOP
=100  1\$aLevy, Leonard Williams,$d1923-
=400  1\$wna$aLevy, Leonard W.$q(Leonard Williams),$d1923-
=670  \\$aHis  Emergence of a free press.
=670  \\$aLCNA 1977-1984.
```
== snip ==

So let us have a look at the record in Workflows:
```bash
Authority ID:	        000000193160
Record format:	        Personal name headings
Source:	                CaOOP
Date authorized:	    NEVER
Authorization level:	AUTHORIZED
Date created:	        4/18/2014
Created by:	            -Q20140418
Date modified:	        NEVER
Modified by:	        ADMIN
Previously modified by:

And in marc record:
Tag	Ind.	Contents
000	 	*****nz**********n******
001	 	000000193160
003	 	CaOOAMICUS
005	 	20091210235959
008	 	200912nx*acnnnaabn********** a*aaa**** |
040		CaOOP|bnnn|cCaOOP
100	1	Levy, Leonard Williams,|d1923-
400	1	|wna|aLevy, Leonard W.|q(Leonard Williams),|d1923-
670		His Emergence of a free press.
670		LCNA 1977-1984.
```

Earlier I created a list of all our authority keys and ids with:
```bash
 selauthority -oKF > AllAuthKeysAndIDs.lst
```
so:
```bash
grep 000000193160 AllAuthKeysAndIDs.lst
558724|000000193160    |
```
therefore:
```bash
echo 558724 | authdump
Symphony $<authority:u> $<dump> 3.4.1 $<started_on> $<tuesday:u>, $<december:u> 23, 2014, 11:30 AM
$(9031)
$(9162)
*** DOCUMENT BOUNDARY ***
FORM=PERSONAL
.000. |az n 0n
.001. |a000000193160
.003. |aCaOOAMICUS
.005. |a20091210235959
.008. |a200912nxbacnnnaabn           a aaa     |
.040. |aCaOOP|bnnn|cCaOOP
.100. 1 |aLevy, Leonard Williams,|d1923-
.400. 1 |wna|aLevy, Leonard W.|q(Leonard Williams),|d1923-
.670. |aHis  Emergence of a free press.
.670. |aLCNA 1977-1984.
  1 $<authority> $(1303)
Symphony $<authority:u> $<dump> $<finished_on> $<tuesday:u>, $<december:u> 23, 2014, 11:30 AM
```
if we isolate the dumped record and the flat file provided from BSLW here is what we get:
```bash
diff Levy_DUMP.flat Levy_BSLW.flat
2,12c2,12
< FORM=PERSONAL
< .000. |az n 0n
< .001. |a000000193160
< .003. |aCaOOAMICUS
< .005. |a20091210235959
< .008. |a200912nxbacnnnaabn           a aaa     |
< .040. |aCaOOP|bnnn|cCaOOP
< .100. 1 |aLevy, Leonard Williams,|d1923-
< .400. 1 |wna|aLevy, Leonard W.|q(Leonard Williams),|d1923-
< .670. |aHis  Emergence of a free press.
< .670. |aLCNA 1977-1984.
---
> FORM=PERSONAL
> .000. |az n 0n
> .001. |a000000193160
> .003. |aCaOOAMICUS
> .005. |a20091210235959
> .008. |a200912nxbacnnnaabn           a aaa     |
> .040.   |aCaOOP|bnnn|cCaOOP
> .100. 1 |aLevy, Leonard Williams,|d1923-
> .400. 1 |wna|aLevy, Leonard W.|q(Leonard Williams),|d1923-
> .670.   |aHis  Emergence of a free press.
> .670.   |aLCNA 1977-1984.
```
Meaning that the flat files are completely different on every line. Since we do not see
any difference visually lets take a look at the binary files:

Viewing the binary version of the flat file dumped from Symphony we see:
```bash
cat Levy_DUMP.flat | od -a
0000000   *   *   *  sp   D   O   C   U   M   E   N   T  sp   B   O   U
0000020   N   D   A   R   Y  sp   *   *   *  nl   F   O   R   M   =   P
0000040   E   R   S   O   N   A   L  nl   .   0   0   0   .  sp   |   a
0000060   z  sp   n  sp   0   n  nl   .   0   0   1   .  sp   |   a   0
0000100   0   0   0   0   0   1   9   3   1   6   0  nl   .   0   0   3
0000120   .  sp   |   a   C   a   O   O   A   M   I   C   U   S  nl   .
0000140   0   0   5   .  sp   |   a   2   0   0   9   1   2   1   0   2
0000160   3   5   9   5   9  nl   .   0   0   8   .  sp   |   a   2   0
0000200   0   9   1   2   n   x   b   a   c   n   n   n   a   a   b   n
0000220  sp  sp  sp  sp  sp  sp  sp  sp  sp  sp  sp   a  sp   a   a   a
0000240  sp  sp  sp  sp  sp   |  nl   .   0   4   0   .  sp   |   a   C
0000260   a   O   O   P   |   b   n   n   n   |   c   C   a   O   O   P
0000300  nl   .   1   0   0   .  sp   1  sp   |   a   L   e   v   y   ,
0000320  sp   L   e   o   n   a   r   d  sp   W   i   l   l   i   a   m
0000340   s   ,   |   d   1   9   2   3   -  nl   .   4   0   0   .  sp
0000360   1  sp   |   w   n   a   |   a   L   e   v   y   ,  sp   L   e
0000400   o   n   a   r   d  sp   W   .   |   q   (   L   e   o   n   a
0000420   r   d  sp   W   i   l   l   i   a   m   s   )   ,   |   d   1
0000440   9   2   3   -  nl   .   6   7   0   .  sp   |   a   H   i   s
0000460  sp  sp   E   m   e   r   g   e   n   c   e  sp   o   f  sp   a
0000500  sp   f   r   e   e  sp   p   r   e   s   s   .  nl   .   6   7
0000520   0   .  sp   |   a   L   C   N   A  sp   1   9   7   7   -   1
0000540   9   8   4   .  nl
0000545
---
cat Levy_BSLW.flat | od -a
0000000   *   *   *  sp   D   O   C   U   M   E   N   T  sp   B   O   U
0000020   N   D   A   R   Y  sp   *   *   *  nl   F   O   R   M   =   P
0000040   E   R   S   O   N   A   L  sp  nl   .   0   0   0   .  sp   |
0000060   a   z  sp   n  sp   0   n  sp  nl   .   0   0   1   .  sp   |
0000100   a   0   0   0   0   0   0   1   9   3   1   6   0  sp  nl   .
0000120   0   0   3   .  sp   |   a   C   a   O   O   A   M   I   C   U
0000140   S  sp  nl   .   0   0   5   .  sp   |   a   2   0   0   9   1
0000160   2   1   0   2   3   5   9   5   9  sp  nl   .   0   0   8   .
0000200  sp   |   a   2   0   0   9   1   2   n   x   b   a   c   n   n
0000220   n   a   a   b   n  sp  sp  sp  sp  sp  sp  sp  sp  sp  sp  sp
0000240   a  sp   a   a   a  sp  sp  sp  sp  sp   |  sp  nl   .   0   4
0000260   0   .  sp  sp  sp   |   a   C   a   O   O   P   |   b   n   n
0000300   n   |   c   C   a   O   O   P  sp  nl   .   1   0   0   .  sp
0000320   1  sp   |   a   L   e   v   y   ,  sp   L   e   o   n   a   r
0000340   d  sp   W   i   l   l   i   a   m   s   ,   |   d   1   9   2
0000360   3   -  sp  nl   .   4   0   0   .  sp   1  sp   |   w   n   a
0000400   |   a   L   e   v   y   ,  sp   L   e   o   n   a   r   d  sp
0000420   W   .   |   q   (   L   e   o   n   a   r   d  sp   W   i   l
0000440   l   i   a   m   s   )   ,   |   d   1   9   2   3   -  sp  nl
0000460   .   6   7   0   .  sp  sp  sp   |   a   H   i   s  sp  sp   E
0000500   m   e   r   g   e   n   c   e  sp   o   f  sp   a  sp   f   r
0000520   e   e  sp   p   r   e   s   s   .  sp  nl   .   6   7   0   .
0000540  sp  sp  sp   |   a   L   C   N   A  sp   1   9   7   7   -   1
0000560   9   8   4   .  sp  nl
0000566
```
Notice how all the lines in the dump file contain:
```bash
.   0   0   1   .  sp   |  a   0   0   0   0   0   0   1   9   3   1   6   0  nl
```
and in BSLW contains:
```bash
.   0   0   1   .  sp   |  a   0   0   0   0   0   0   1   9   3   1   6   0  sp  nl
```
Technically the trailing empty space (not the nl) is part of the naming pattern.
I am now going to test the effects of this with an experiment. I have modified
the BSLW flat file with some minor edits and reloaded it.
```bash
cat Levy_LOAD.flat | authload -fc -mu
Symphony $<authority> $<load> 3.4.1 $<started_on> $<tuesday:u>, $<december:u> 23, 2014, 12:19 PM
$(9180)
$(11223)
$(9186)
$(9182)
558724|
  12 $(1401)
  1 $<authority> $(1402)
  0 $<authority> $(1403)
  0 $<authority> $(1404)
  1 $<authority> $(1405)
Symphony $<authority> $<load> $<finished_on> $<tuesday:u>, $<december:u> 23, 2014, 12:19 PM
bash-3.2$ echo 558724 | authdump
Symphony $<authority:u> $<dump> 3.4.1 $<started_on> $<tuesday:u>, $<december:u> 23, 2014, 12:20 PM
$(9031)
$(9162)
*** DOCUMENT BOUNDARY ***
FORM=PERSONAL
.000. |az n 0n
.001. |a000000193160
.003. |aCaOOAMICUS
.005. |a20091210235959
.008. |a200912nxbacnnnaabn           a aaa     |
.040. |aCaOOP|bnnn|cCaOOP
.100. 1 |aLevy, Leonard Williams,|d1923-
.400. 1 |wna|aLevy, Leonard W.|q(Leonard Will.i.ams),|d1923-
.670. |aHis  Emergence of a flea press.
.670. |aLCNA 1977-1984.
  1 $<authority> $(1303)
Symphony $<authority:u> $<dump> $<finished_on> $<tuesday:u>, $<december:u> 23, 2014, 12:20 PM
```
And the file matches so the conclusion is trailing white space has no effect on matching numeric authority ids.
After some more testing and bug fixes I perform the following experiment.
I preload all the authorities sent by BSLW. I then load the updated authorities for NAMEs with:
```bash
cat test.flat | ./authority.pl -p"./total.flat"
...
**warning: ambiguous authority id, 001='n 2012048589', 016='1022H5849'
Analysis:
   update-auth count:     195
      pre-auth count:  226285
                 016:      38
               match:       0
                 001:     195
```
Searching for `2012048589` in all the authority IDs we have loaded we find:
```bash
grep 2012048589 AllAuthKeysAndIDs.lst
800468|N2012048589     |
```
It appears that Symphony has UC and removed white space from the authority ID on load.
To test I create a flat file for myself:
```bash
 cat andrew.flat
*** DOCUMENT BOUNDARY ***
FORM=PERSONAL
.000. |az n 0n
.001. |an ANDREW001
.003. |aCaOOAMICUS
.005. |a20091210235959
.008. |a200912nxbacnnnaabn           a aaa     |
.040.   |aCaOOP|bnnn|cCaOOP
.100. 1 |aNisbet, Leonard Williams,|d1923-
.400. 1 |wna|aNisbet, Leonard W.|q(Leonard Will.i.ams),|d1923-
.670.   |aHis  Emergence of a flea press.
.670.   |aLCNA 1977-1984.

and load
cat andrew.flat | authload -fc -mb
Symphony $<authority> $<load> 3.4.1 $<started_on> $<tuesday:u>, $<december:u> 23, 2014, 1:35 PM
$(9180)
$(11224)
$(9186)
$(9182)
903430|
  12 $(1401)
  1 $<authority> $(1402)
  0 $<authority> $(1403)
  1 $<authority> $(1404)
  0 $<authority> $(1405)
Symphony $<authority> $<load> $<finished_on> $<tuesday:u>, $<december:u> 23, 2014, 1:35 PM
```


search for 'NANDREW001' and find:
```bash
000	 	*****nz**********n******
001	 	n ANDREW001
003	 	CaOOAMICUS
005	 	20091210235959
008	 	200912nx*acnnnaabn********** a*aaa**** |
040		CaOOP|bnnn|cCaOOP
100	1	Nisbet, Leonard Williams,|d1923-
400	1	|wna|aNisbet, Leonard W.|q(Leonard Will.i.ams),|d1923-
670		His Emergence of a flea press.
670		LCNA 1977-1984.
A search for 'n ANDREW001' fails.
I modify the file to 
*** DOCUMENT BOUNDARY ***
FORM=PERSONAL
.000. |az n 0n
.001. |aNANDREW001
.003. |aCaOOAMICUS
.005. |a20091210235959
.008. |a200912nxbacnnnaabn           a aaa     |
.040.   |aCaOOP|bnnn|cCaOOP
.100. 1 |aNisbet, Leonard Williams,|d1923-
.400. 1 |wna|aNisbet, Leonard W.|q(Leonard Will.i.ams),|d1923-
.670.   |aHis  Emergence of a flea press.
.670.   |aLCNA 1977-1984.

cat andrew.flat | authload -fc -mb
Symphony $<authority> $<load> 3.4.1 $<started_on> $<tuesday:u>, $<december:u> 23, 2014, 1:40 PM
$(9180)
$(11224)
$(9186)
$(9182)
903430|
  12 $(1401)
  1 $<authority> $(1402)
  0 $<authority> $(1403)
  0 $<authority> $(1404)
  1 $<authority> $(1405)
  
THE KEYS MATCH when I 'NANDREW001', 'n ANDREW001'
...
```
typical id without processing:'nr 98023852' 
```bash
...
Analysis:
   update-auth count:     195
      pre-auth count:  384994
                 016:      38
               match:      19
                 001:     195

...
```
typical id with processing:'NR98023852'
```bash
...
Analysis:
   update-auth count:     195
      pre-auth count:  384994
                 016:      38
               match:     194
                 001:     195

				 
				 
=============================
```
## Loading

Once fixed loading takes place with:
```bash
cat NAME.CHG.mrc.fix.flat | authload -fc -mb
```
which overlays matching records matching on `001` (`-fc`) and update if possible, and create otherwise (`-mb`)
```bash
 ...
 907123|
 907124|
**Entry ID not found in format:  entry = 024 format = PERSONAL
*** DOCUMENT BOUNDARY ***
FORM=PERSONAL
.000. |az n 0c
.001. |aNO2008020240
.003. |aDLC
.005. |a20140925091617.0
.008. |a080206n| azannaabn          |a aaa     c
.010.   |ano2008020240|znr 92044064
 611191|
 ...
 907163|
 220997 $(1401)
  11230 $<authority> $(1402)
  78 $<authority> $(1403)
  3733 $<authority> $(1404)
  7497 $<authority> $(1405)
Symphony $<authority> $<load> $<finished_on> $<tuesday:u>, $<december:u> 30, 2014, 10:46 AM
```

## Things to think about for production

If you normalize a flat file and then load it, the authority will have a `001` field normalized, which BSLW 
will not be able to match again in the futre.

Process suggestion: use selauthority to output all our existing keys and authids, then use the -i to separate 
files from BSLW into New and Updates. The updates get get loaded as updates and creates as creates. Or even 
BETTER get the script to not normalize authorities that it doesn't recognize, then on create or update and the
whole thing gets done in one fell swoop!!

In addition:

So now we want to send an update and Chris recommends that we run the flat file he created as a dump through
the script. The flat file is a dump of our authority table so it should match 100% since we are comparing our
authorities with our authorities, but...
== snip ==
```bash
\*warning: failed to match 'BIK-4340'
*warning: failed to match 'AMX-3455'
Analysis:
           PERSONAL :    3072
   update-auth count:    3636
        ambiguous ID:       6
                 016:     496
            no match:    2105
               match:    1529
            MEETING :       8
  update w/o auth id:       2
      pre-auth count:  387428
           GEOGRAPH :      12
          LCCHILDSH :       1
               LCSH :      87
              TITLE :      13
                 001:    7220
          CORPORATE :     443
percent match: 42.05
```
== snip ==

Why the **42%** match? Turns out Chris had dumped the authorities with auth id in the 035. Fixed and run again, we got the 
same results. Why?

Turns out that when you dump an authority with 'authdump -ki001 it puts an additional 001 field into the flat file but 
at least it is predictable, that is the real auth id is in the first field.

Then I had to modify the script to not process any second or greater `001` fields. Once done we get much better results:
```bash
*warning: ambiguous authority id, 001='XX904649', 016='0072D6091'
*warning: ambiguous authority id, 001='XX904649', 016='0072D6091'
*warning: ambiguous authority id, 001='N2011071231', 016='1022B1490'
*warning: ambiguous authority id, 001='N2011071231', 016='1022B1490'
*warning: failed to match 'N96014505T'
*warning: ambiguous authority id, 001='N2010045708', 016='1004K4141'
*warning: ambiguous authority id, 001='N2010045708', 016='1004K4141'
Analysis:
           PERSONAL :    3072
   update-auth count:    3636
        ambiguous ID:       6
                 016:     496
            no match:       1
                 010:    2218
               match:    3635
            MEETING :       8
      pre-auth count:  387431
           GEOGRAPH :      12
          LCCHILDSH :       1
               LCSH :      87
              TITLE :      13
                 001:    7220
          CORPORATE :     443
percent match: 99.97
```
## NOTE:
The 'N96014505T' is a poorly modified record that accidentally had a 't' attached. Once attached there is no way to 
remove it that I can think of. WF does not find it to fix it, and you cannot overlay the flat file because the match
is on the 001 field; the field you are trying to fix. I created a ticket with SD to fix and now that is done.

### related email
This email sent to Stephanie Hansen on Jan 7, 2015.

== snip ==
```
Here is a sample MARC file of our adds and changes from May 1 2014 inclusive. 

As we discussed, when I dump a specific authority such as ‘n  94091369‘, requesting the system place the authority ID in tag 001 I get:
*** DOCUMENT BOUNDARY ***
FORM=PERSONAL
.000. |az n  c
.001. |aN94091369
.001. |aAMX-3455
.005. |a20031003052447.0
.008. |a940922n| acannaabn          |a aaa
.010. |an  94091369
.035. |a(OCoLC)oca03685773
.040. |aDLC|beng|cDLC|dPPi-MA
.100. 1 |aSuzuki, Pat
.400. 1 |aSuzuki, Chiyoko
.670. |aFlower drum song, 1959?:|blabel (Pat Suzuki)
.670. |aInternet Movie Database, Oct. 2, 2003|b(Pat Suzuki; b. Chiyoko Suzuki, Sept. 23, early 1930s, Cressy, Calif.)
.670. |aBio. and geneal. master index on GaleNet, Oct. 2, 2003|b(Suzuki, Pat, 1930?- ; Suzuki, Pat, 1931- ; Suzuki, Pat)
.675. |aContemp. theatre, film, and television, v. 1-49;|aVariety's ww in show business, 1989

I want to confirm that BSLW will select the first 001 as a match point, and secondly that BSLW can run the 
script you mentioned in our phone conversation to match authorities stored in your database when comparing 
001 match; in this case matching on your stored value  ‘n  94091369‘.
```
== snip ==

## More on Authority Updates
Once we got the correct records back from BSLW, we loaded them and throttled adutext to index only 20,000 records.


Note that subject header changes end up touching 100,000 bib records which means that adutext run-time blew up by an
additional 6 hours. Also because the bibs were touched, the OCLC update was unusually large.


Reports on adutext performance:
On test machine we are going to set up some experiments. I am first loading all TITLE.NEW.MRC, and SERIES.NEW.MRC
that BSLW gave us with the exact same process except that I am not sorting the keys in the authedit.keys file.
```bash
Symphony $<authority> $<load> $<finished_on> $<tuesday:u>, $<february:u> 24, 2015, 4:21 PM
[authbot.sh] copying AllAuth.keys to /s/sirsi/Unicorn/Work/Batchkeys/authedit.keys
[authbot.sh] successful.
bash-3.2$ cat  /s/sirsi/Unicorn/Work/Batchkeys/authedit.keys | wc -l
   20096

Now we will run the authbot on the next set; NAME.NEW.MRC and SUBJ.NEW.MRC in that order. We will not sort the keys.
This will bring the test machine upto par with the production as far as authorities are concerned, AND we can start
to monitor adutext runs on test to see how a random selection of keys affects runtime over several days.

Symphony $<authority> $<load> $<finished_on> $<wednesday:u>, $<february:u> 25, 2015, 8:06 PM
[authbot.sh] ** Warning:   531020 keys found in AllAuth.keys but 100000 requested.
[authbot.sh] ** Warning: split AllAuth.keys and copy the a section to '/s/sirsi/Unicorn/Work/Batchkeys/authedit.keys'.
bash-3.2$ ls /s/sirsi/Unicorn/Work/Batchkeys/authedit.keys
/s/sirsi/Unicorn/Work/Batchkeys/authedit.keys: No such file or directory
bash-3.2$ ls
AllAuth.keys               authbot.sh                 bibmatchpoint.sh           fix.flat.err               log.txt                    NAME.NEW.MRC               prepmarc.sh                SUBJ.NEW.MRC
AllAuthKeysAndIDs.lst      authority.pl               fix.flat                   fix.flat.err.TITLE.SERIES  Makefile                   NAME.NEW.MRC.flat          SERIES.NEW.MRC             SUBJ.NEW.MRC.flat
```
Testing on production shows a big hump of time used by adutext by night over the nights that subj ran. Tests on test 
machine show no such hump when all the keys are randomized.

More to follow.

`authority.pl` - fixes flat files by normalizing them and reports on key metrics for this type of file.
`prepmarc.sh`  - prepares MARC files in to flat files and conditionally handles DEL.MRC files. Both this script and authority.pl
       are safe to run by hand any time, as they do not modify the ILS in any way.
`authbot.sh`   - is a driver script that runs prepmarc.sh and authority.pl in a coordinated fashion. It if prepmarc.sh produces
       a DEL.MRC.keys file it will use remauthority to remove the authorities. If a fix.flat file exists, it will load the 
       flat file with authload with switches to update if possible and create anything it can't find.
	   
	   
## Issues
Staff have noticed some problems: 
```bash
bash-3.2$ echo 1386471 | catalogdump -om | convMarc -tu
Symphony $<catalog:u> $<dump> 3.4.1 $<started_on> $<wednesday:u>, $<april:u> 8, 2015, 4:38 PM
$(1222)
$(3364)
$(3398)
$(3394)
  1 $<catalog> $(1303)
  1 $<bib> $<MARC> $(1303)
  0 $<item> $(1303)
Symphony $<catalog:u> $<dump> $<finished_on> $<wednesday:u>, $<april:u> 8, 2015, 4:38 PM
01039cas a22003492  4500001001100000003000400011005001700015006001900032007001500051008004100066022001400107035002300121035002200144035001900166035002000185040002300205042001100228050000700239099002000246222002400266245004000290264004300330310002600373336002100399337002300420338003200443596000600475651003700481776005800518780003300576856008000609
ebs106803eEBZ20150320204613.0m        d  ||||||cr unu||||||||800122c19uu9999quczn ne      0   a0eng d  a0384-1294  
a(Sirsi) ebs106803e  a(CaAE) ebs106803e  a(OCoLC)5901687  a(EBZ)ebs106803e  aVtU dEBZdUtOrBLW  aisds/c14aAN  
aInternet Access 0aGazetteb(Montreal)04aThe Gazetteh[electronic resource]. 1aMontreal :b[publisher not identified]  
aDaily except Sundays.  atext2rdacontent  acomputer2rdamedia  aonline resource2rdacarrier  a1 0aMontraeal (Quaebec)
vNewspapers.1 tThe Gazettex0384-1294 w(OCoLC)5901687 wcn 8531167200tMontraeal gazettex0839-32574 
zRead it Online.uhttp://atoz.ebsco.com/direct.asp?id=8717&reso1 MARC records read
0 MARC records in error
1 records successfully converted.
0 records converted with warnings.  See error log.
urceid=106803


cat key 1386471
bash-3.2$ echo ebs106803e | selcatalog -iF | catalogdump -oF
Symphony $<catalog> $<selection> 3.4.1 $<started_on> $<wednesday:u>, $<april:u> 8, 2015, 4:47 PM
$(2271)
$(1232)
Symphony $<catalog:u> $<dump> 3.4.1 $<started_on> $<wednesday:u>, $<april:u> 8, 2015, 4:47 PM
  1 $<catalog> $(1308)
  1 $<catalog> $(1309)
Symphony $<catalog> $<selection> $<finished_on> $<wednesday:u>, $<april:u> 8, 2015, 4:47 PM
$(1222)
$(3363)
$(3398)
$(3394)
*** DOCUMENT BOUNDARY ***
FORM=SERIAL
.000. |aas2 0c
.001. |aebs106803e
.003. |aEBZ
.005. |a20150320204613.0
.006. |am        d  ||||||
.007. |acr unu||||||||
.008. |a800122c19uu9999quczn ne      0   a0eng d
.022.   |a0384-1294
.035.   |a(Sirsi) ebs106803e
.035.   |a(CaAE) ebs106803e
.035.   |a(OCoLC)5901687
.035.   |a(EBZ)ebs106803e
.040.   |aVtU |dEBZ|dUtOrBLW
.042.   |aisds/c
.050. 14|aAN
.099.   |aInternet Access
.222.  0|aGazette|b(Montreal)
.245. 04|aThe Gazette|h[electronic resource].
.264.  1|aMontreal :|b[publisher not identified]
.310.   |aDaily except Sundays.
.336.   |atext|2rdacontent
.337.   |acomputer|2rdamedia
.338.   |aonline resource|2rdacarrier
.596.   |a1
.651.  0|aMontraeal (Quaebec)|vNewspapers.
.776. 1 |tThe Gazette|x0384-1294 |w(OCoLC)5901687 |wcn 85311672
.780. 00|tMontraeal gazette|x0839-3257
.856. 4 |zRead it Online.|uhttp://atoz.ebsco.com/direct.asp?id=8717&resourceid=106803
  1 $<catalog> $(1303)
  1 $<bib> $<MARC> $(1303)
  0 $<item> $(1303)
Symphony $<catalog:u> $<dump> $<finished_on> $<wednesday:u>, $<april:u> 8, 2015, 4:47 PM
```
Notice how Montreal is spelt correctly in tag `222` but incorrectly in the `780`.

This is what we sent to BSLW: '`20150320_EPL_Catalog_Records.flat`'
Line No.
```bash
4312399 *** DOCUMENT BOUNDARY ***
4312400 FORM=LCSH
4312401 .000. |aas2 0c
4312402 .001. |aebs106803e
4312403 .003. |aEBZ
4312404 .006. |am        d  ||||||
4312405 .007. |acr|unu||||||||
4312406 .008. |a800122c19uu9999quczn ne      0   a0eng d
4312407 .022.   |a0384-1294
4312408 .035.   |a(Sirsi) ebs106803e
4312409 .035.   |a(CaAE) ebs106803e
4312410 .035.   |a(OCoLC)5901687
4312411 .035.   |a(EBZ)ebs106803e
4312412 .040.   |aVtU |dEBZ
4312413 .042.   |aisds/c
4312414 .050. 14|aAN
4312415 .099.   |aInternet Access
4312416 .222.  0|aGazette|b(Montreal)
4312417 .245. 04|aThe Gazette|h[electronic resource].
4312418 .260.   |aMontreal.
4312419 .310.   |aDaily except Sundays.
4312420 .651.  0|aMontraeal (Quaebec)|vNewspapers.
4312421 .776. 1 |tThe Gazette|x0384-1294 |w(OCoLC)5901687 |wcn 85311672
4312422 .780. 00|tMontraeal gazette|x0839-3257
4312423 .856. 4 |zRead it Online.|uhttp://atoz.ebsco.com/direct.asp?id=8717&resourceid=106803
4312424 .596.   |a1
```
To fix this I have started to reverse engineer the way that ANSEL is corrupted on output.

## Prepmarc.sh issues
```bash
 ...
@@PBK#xFICTION#zJUVENILE#  #aChildren's fiction - Series A#vPBK#wASIS#i312211160
@@57998#lJPBKSER#mEPLZORDER#p4.53#tJPBK#xFICTION#zJUVENILE#  #aChildren's fictio
@@n - Series A#vPBK#wASIS#i31221116058061#lJPBKSER#mEPLZORDER#p4.53#tJPBK#xFICTI
@@ON#zJUVENILE##
**
  0 $(11603)
  0 $(11604)
  5173 $<bib_s> $(1402)
  5 $<bib_s> $(1403)
  0 $<bib_s> $(1404)
  0 $<bib_s> $(1412)
  0 $(11609)
  5168 $(11607)
Symphony $<catalog:u> $<marc:U> $<load:u> $<finished_on> $<friday:u>, $<may:u> 13, 2016, 11:27 AM
*.MRC: No such file or directory
[prepmarc.sh] cleaning out old files
tmp.19826: No such file or directory
*.MRC: No such file or directory
caution: filename not matched:  *.MRC
*.MRC: No such file or directory
[prepmarc.sh] cleaning out old files
tmp.19835: No such file or directory
bash-3.2$ ls
AllAuthKeysAndIDs.lst  authbot.sh             bibmatchpoint.sh       DEL.MRC.flat           log.txt                prepmarc.sh
authbot.log            authority.pl           C.zip                  DEL.MRC.keys           Makefile
bash-3.2$ ll
total 27181
drwx------   2 sirsi    sirsi         14 May 13 11:27 .
-rw-------   1 sirsi    sirsi          0 May 13 11:27 ._marc_.txt
drwx------   4 sirsi    sirsi          4 Mar  2  2015 ..
-rw-------   1 sirsi    sirsi    13726112 May 13 11:22 AllAuthKeysAndIDs.lst
-rw-------   1 sirsi    sirsi       1197 May 13 11:27 authbot.log
-rwx------   1 sirsi    sirsi      13225 May 13 10:21 authbot.sh
-rwx------   1 sirsi    sirsi      16650 May 13 10:21 authority.pl
-rwx------   1 sirsi    sirsi       1895 May 13 10:21 bibmatchpoint.sh
-rw-r--r--   1 sirsi    sirsi      79478 May 13 09:51 C.zip
-rw-------   1 sirsi    sirsi      11440 May 13 11:22 DEL.MRC.flat
-rw-------   1 sirsi    sirsi          0 May 13 11:22 DEL.MRC.keys
-rw-------   1 sirsi    sirsi       1464 May 13 11:27 log.txt
-rwx------   1 sirsi    sirsi        681 Jul 22  2015 Makefile
-rwx------   1 sirsi    sirsi       6256 May 13 10:21 prepmarc.sh
 ...
 ```