{smcl}
{cmd:help SMutilities}
{hline}

{p2colset 3 14 14 2}{...}
{p2col :{bf:StackMe utility programs} {hline 2}} This help text describes utility programs that supplement 
the {bf:StackMe} package of Stata commands for pre-processing and {help reshapeing} (generally survey) 
data in preparation for multi-level or hierarchical (sometimes known as contextual) analysis.{p_end}

{p2colreset}{...}

{marker Introduction}
{title:Introduction}

{pstd}
The {cmd:stackMe} package is a collection of tools for generating and manipulating stacked {help reshape:(reshape}d) 
data. Resulting datasets have two features that set them apart from conventional survey datasets. {bf:First}, they are intimately 
Tied to the {help stackme##Datastacking:contextual structure} within which they were created. Attempting to use them without 
reference to that structure will produce nonsense findings. {bf:Second}, because data collection is an ongoing process in 
relevant academic fields of study, {bf:stackMe} datasets have to be open to expansion. For this reason the management of 
{it:{cmd:linkage variables}} plays a central role.{p_end}

{pstd}
This helpfile documents the use of three utility progrograms, provided with the {bf:stackMe} package for the purpose 
of managing relevant {help stackme##stackmespecialnames:special variables}, as follows:{p_end}

{pstd}{help SMutilities##SMcontextvars:{ul:SMcon}textvars} utility program for managing variables that define a dataset's 
hierarchical contexts (should be invoked immediately after command {bf:{help use}} has opened the dataset for processing 
by other {bf:stackMe} commands).{p_end}

{pstd}{help SMutilities##SMitemnames:{ul:SMite}mnames} utility program for managing variables that link stacked to unstacked 
observations (these linkages are provided semi-automatically by command {help genstacks:{ul:genst}acks} but this utility 
is needed if those linkages are to be permanently changed (temporary changes – for the duration of the {bf:stackMe} command) 
that optioned the change – can be accomplished by means of the option {opt:ite:mname} provided by all {bf:stackMe} commands).{p_end}

{pstd}{help SMutilities##SMfilename:{ul:SMite}mnames} utility program for managing 


{pstd}
These three utility programs are documented below.


{marker SMcontextvars}
{title:SMcontextvars}

{title:Syntax}

{p 6 14 2}
{cmdab:SMcon:textvars} [{varlist}]  [{cmd:,} {it:option}]{p_end}

{p 4 4 2}
The varlist should list names of variables defining (or re-defining) the contexts that will characterize the data when 
stacked (or that do characterize already stacked data). If the (optional) {varlist} is present then it may be followed 
by just one of the following options, if desired, as follows:

{synoptset 19 tabbed}{...}
{synopthdr}
{synoptline}

{p2colset 4 15 15 2}{synopt :{opt dis:play}} (the only option that can accompany a varlist) display the names 
and labels of variables now established as defining the contexts within which the data are organized (often {it:country} 
and {it:year}).{p_end}
{synopt :{opt noc:ontexts}} (may not follow a varlist) define this dataset as one with no contexts.{p_end}
{synopt :{opt cle:ar}} (may not follow a varlist) remove the characteristic that defines the contexts within which 
this dataset will be or has been stacked.{p_end}

{marker Description}
{title:Description}

{pstd}
The {cmdab:SMcon:textvars} utility program is used to initialize a dataset for use with {bf:stackMe} commands. It defines 
the hierarchical structure that characterizes the dataset (or will characterize the dataset when stacked). Alternatively 
it initializes a conventional unstacked dataset for use with {bf:stackMe} commands by defining it as having no contexts.
Note that a dataset with no context distinctions can still be stacked; but such a dataset would be well-served by existing 
Stata commands.

{marker Examples}
{title:Examples}

{pstd}The following command would be used to initialize a potentially hierarchical dataset for use with {bf:stackMe} 
by providing it with what Stata calls a 'data characteristic' that defines its hierarchical structure; also providing 
an optional description of the resuting variables and their labels if any:{p_end}

{phang2}{cmd:. SMcontextvars country year, describe}{p_end}

{pstd}The following command would be used to discard the Stata characteristic that defines the dataset as a {bf:stackMe} 
dataset:{p_end}

{phang2}{cmd:. SMcontextvars  , clear}{p_end}

{marker Generatedvariables}
{title:Generated variables}

{pstd} {cmdab:SMcon:textvars} does not generate any variables. It merely ascribes a special status to certain variables 
that will be central to the process of {help reshape}ing the dataset into stacked format and governing the pre-processing of 
the stacked data thereafter. 




{marker SMitemnames}
{title:SMitemnames}

{title:Syntax}

{p 6 14 2}
{cmdab:SMite:mvars} [{varlist}]  [{cmd:,} {it:option}]{p_end}

{p 4 4 2}
The varlist may be used to name one or two so-called {it:{bf:item}}s (referred to as {it:{bf:SMitem}} and 
{it:{bf:S2item}}) defining (or re-defining) linkage variables that will supplement the {bf:SMstkid} variable in 
identifying the items (members of what is often called a "battery" of survey items) that will (have been) 
reshaped into separate 'stacks' of items (see the {cmd:stackme} help text on {help stackme##Datastacking:data stacking}
for more on this topic). The (optional) {varlist}, if present, may be followed by just one of the following options:{p_end}

{synoptset 19 tabbed}{...}
{synopthdr}
{synoptline}

{p2colset 4 15 15 2}{synopt :{opt dis:play}} (the only option that can accompany a varlist). Display the names 
and labels of variables now linked to the itemname(s) ({it:{bf:SMitem}} and {it:{bf:S2item}}) that connect stacked 
observations to the items that were variables before stacking.{p_end}

{synopt :{opt S2i:tem}} (may not follow a 
varlist but may be used in conjunction with the {opt dis:play} option). Establish an itemname for a doubly-stacked 
dataset without affecting the itemname ({it:{cmd:SMitem}}) associated with data when it was singly-stacked.{p_end}

{synopt :{opt clear}} (may not follow a varlist). Remove the data characteristic(s) that defines all itemvars.{p_end}

{marker Description}
{title:Description}

{pstd}
The {cmdab:SMitemvars} utility program can be used to create what Stata calls 'data characteristics' naming the linkage 
variables that connect stacked observations to the variables that were battery items before stacking. These linkages 
are usually established by the {bf:stackMe} {cmdab:genst:acks} command, with variable names options by the user. However, 
the names can be supplied separately (or changed) using this utility program. The linkages are anchored by two  
{help stackme##stackmespecialnames:special names} {it:{cmd:SMitem}} and {it:{cmd:S2item}} which provide the relevant 
linkages in singly-stacked and doubly-stacked data, respectively. Doubly-stacking is an esoteric concept largely beyond 
the purview of this help file. See the helpfile named {help SMwriteyourown} for more on this topic.{p_end}


{marker Examples}
{title:Examples}

{pstd}The following command would be used to establish what Stata calls a "data characteristic" naming the {it:{cmd:SMitem}} 
linkage variable for a conventional (singly-stacked) dataset, also providing an optional description of the linked 
variable and its variable label if any:{p_end}

{phang2}{cmd:. SMitemvars partynames, describe}{p_end}

{pstd}The following command would be used to discard the Stata characteristic that defines the party names linkage 
established by the first example, above:{p_end}

{phang2}{cmd:. SMitemvars  , clear}{p_end}

{marker Generatedvariables}
{title:Generated variables}

{pstd} {cmdab:SMite:mvars} does not generate any variables. It merely ascribes a special status to certain variables 
that will be central to the process of linking observations in stacked format to the variables that were battery items 
before stacking. see the {cmd:stackme} help text regarding {help stackme##Datastacking:data stacking} for more about 
the structure of stacked data.




{marker SMfilename}
{title:SMfilename}

{title:Syntax}

{p 6 14 2}
{cmdab:SMfil:ename} [{filename}]  [{cmd:,} {it:option}]{p_end}

{p 4 4 2}
The filename, if present, should name the file as it is currently named in the computer's file structure. The (optional) 
filename may occasionally be needed to correct the name that is held as a characteristic of each {bf:stackMe} datafile 
(telling that file what name is used to access it within the computer's file structure). This name will automatically 
be updated to reflect the changing nature of the file as it is progressively stacked and (perhaps) doubly-stacked. 
But things can go wrong and this utility can change the name by which a file is known to {bf:stackMe} commands, if 
necessary. The (optional) filename, if present, may be followed by just one of the following options:

{synoptset 19 tabbed}{...}
{synopthdr}
{synoptline}

{p2colset 4 15 15 2}{synopt :{opt dis:play}} (the only option that can accompany a filename). Display the name of the 
currently {bf:{help use}}d Stata datafile that will be (or is already being) pro-processed by {bf:stackMe} commands. 
This option also displays the directory path leading to that filename. That path can be updated, if necessary, by means 
of the following option:{p_end}

{p2colset 4 15 15 2}{synopt :{opt dir:path}} displays a standard Stata file open dialog box initialized with the existing 
directory path and filename. The desired directory path can be established in the usual way before clicking 'ok'. Doing 
so will have no effect on the computer's file structure but will just update the file path recorded in the relevant 
dataset characteristic. If desired, the same dialog box can be used to change the filename, averting the need to enter 
the desired name on the {help SMfilename:{ul:SMfil}ename} command line.{p_end}

{p2colset 4 15 15 2}{synopt :{opt ale:a}} (may not follow a varlist) removes the filename and dirpath characteristics from 
the {bf:stackMe} dataset.{p_end}


{marker Description}
{title:Description}

{pstd}
The {cmdab:SMfilename} utility may never be needed unless you want to re-organize the file structure on your computer, or 
in response to some peculiar error condition. It can be used to display and/or change the filename and directory path that 
gives access to the file containing these data characteristics. It should be stressed that this utility does not change 
anything on your computer's file directory; only two of the data characteristics held in the datafile (along with such 
characteristics as the file label and variable labels) are affected.

{marker Examples}
{title:Examples}

{pstd}The following command would be used to change the filename and displaying the resulting data characteristic.{p_end}

{phang2}{cmd:. SMfilename , display}{p_end}

{pstd}The following command would be used to bring up a standard Stata file open dialog box in which to change the filename 
and/or directory path, as might be needed had the file been moved to a different directory.{p_end}

{phang2}{cmd:. SMfilename , dirpath}{p_end}


{marker Generatedvariables}
{title:Generated variables}

{pstd} {cmdab:SMfilename} does not generate any variables. It merely records as data characteristics, and/or displays the 
filename and directory path that would have been followed in order to open (use) the file where these characteristics are 
recorded.
