{smcl}
{cmd:help stackme}
{hline}

{title:Title}

{p2colset 5 20 20 2}{...}
{p2col :stackme {hline 2}}Tools for creating, manipulationg and pre-processing stacked 
data-sets for hierarchical (multi-level) analysis{p_end}
{p2colreset}{...}

{title:Introduction}

{pstd}
The {cmd:stackme} package is a collection of tools for the analysis of stacked 
({help reshape:reshape}d) data. In the academic subfield of electoral studies this type of 
analysis is also strongly connected to the use of PTV variables (hence the original 
PTVTools package that evolved into StackMe); but specific StackMe commands are now 
mostly documented in more general terms to accommodate usage across all academic 
fields of study that employ hierarchical (multi-level) datasets. In electoral survey 
research, the PTV acronym refers to Propensities To Vote: batteriesof items 
holding the self-reported probability that the respondent will {it:ever} vote 
for a specific political party, and designed as indicators of what Downs (1957) 
referred to as "electoral utilities" (van der Eijk et al., {it:Electoral Studies} 2006; van 
der Eijk and Franklin, {it:Elections and Voters}, Palgrave Macmillan 2009).{p_end}

{pstd}
Such analyses make rather special demands both in terms of methods of analysis and in terms 
of the data being analysed. StackMe pre-processes relevant (often survey) data in a 
variety of ways to suit it for ensuing hierarchical analyses.{break}

{pstd}
Firstly, data {it:stacking} is usually involved, implying that - in Stata terminology - analysis 
may call for data in {it:long} rather than in {it:wide} format (see {help reshape:reshape}); 
and analysis may focus on {it:response}-level data rather than {it:respondent}-level data, 
with responses (at the lowest level of analysis) nested (stacked) within respondents. 
However, StackMe facilitates the reshaping of a dataset with multiple contexts (e.g. countries)
each with possibly different numbers of items (e.g. political parties) in the battery(ies) to be 
stacked. Batteries of different lengths imply missing data for all cases in certain contexts, 
a structure that would be hard to accommodate without elaborating Stata's native commands. After 
stacking (reshaping), each respondent is represented by multiple rows in the data matrix, one for 
each response that, before stacking, was not entirely missing.{break}
   NOTE: In conventional comparative survey data (e.g. the European Social Survey or surveys 
post-processed by the Comparative Study of Electoral Systems) a fair number of question 
batteries are largely empty so as to accommodate data from countries whose surveys had 
larger numbers of battery items (e.g. political parties). After reshaping, such surveys produce 
many rows that are missing for all but respondents from a single (or very few) countries. 
StackMe avoids burdoning memory and filespace with rows that consist entirely of missing data 
due to such happenstances.{break}

{pstd}
Secondly, the dependent variable is usually generalized to accommodate multiple contexts. Thus, 
while in electoral studies conducted in one country a researcher might seek to answer a research 
question such as "why do people vote Conservative?", with multiple countries having different 
party systems that question might need to be reconceptualized in terms of votes for a 
{it:generic} party – {it:any} party: with a question like "why do parties receive electoral 
support?" Such reconcptualization involves moving up the ladder of conceptual 
generality, which also happens when "father" is viewed as a "family" member or 
"school" is viewed as an "educational establishment". Such reconceptualizations produce 
comparability across contexts if these involve different party systems or family structures or 
educational systems, as is common. They also affect {it:independent} variables, which have to be 
reformulated to focus on their affinities with the dependent variable before they can be used in 
a stacked analysis. StackMe generates two types of affinity: proximities (distances) and, for 
non-spatial items, so-called {it:y-hat}s. The original purpose was to facilitate use of ptv 
analysis as a substitute for discrete choice modeling, employing directly-measured preferences 
(utilities) rather than deriving these retrospectively from analysis of choices made. But analysis 
of discrete choice data can benefit just as much from many of the facilities that StackMe provides.


{title:Description}

{pstd}
The {cmd:StackMe} package includes the following commands:

{p2colset 5 17 19 2}{...}
{p2col :{bf:{help iimpute:iimpute}}}(Context-wise) incremental simple or multiple imputation of 
missing data within a battery of variables, taking advantage of within-battery interrelationships 
(additional functions have been taken over by Stata's {help mi:{bf:mi}} command){p_end}
{p2col :{bf:{help genstacks:genstacks}}}(Context-wise) reshaping of a dataset for response-level 
analysis{p_end}
{p2col :{bf:{help gendist:gendist}}}(Context-wise) generation of distances between a 
spatially-located variable and each item in a battery of spatial items, with customizable 
treatment of missing data{p_end}
{p2col :{bf:{help genyhats:genyhats}}}(Context-wise) generation of {it:y-hat} affinity measures 
linking indepvars to ptvs or other depvars{p_end}
{p2col :{bf:{help gendummies:gendummies}}}generation of set(s) of dummy variables employing, as 
numeric suffixes for names of variables in each set, the numeric values actually found{p_end}
{p2col :{bf:{help genmeans:genmeans}}}generation of (optionally weighted) means of variables within 
contexts (similar to Stata's {help egen:{bf:egen}} command with the {bf:by} option, but 
permitting calculation of weighted means){p_end}
{p2col :{bf:{help genplace:genplace}}}generation of spatial placements at the battery level 
(e.g. legislature or government level if the battery items relate to political parties). Placements 
can optionally be weighted by the (weighted) number of respondents and/or by substantively 
meaningful weights (e.g. proportions of seats or ministries controlled by parties that are members 
of a government).{p_end}

{pstd}
These tools largely duplicate existing commands in Stata but operate on data with multiple contexts 
(eg. countries or country-years) each of which requires separate handling. Moreover, all of the 
commands in {cmd:stackme} have additional features not readily duplicated with existing Stata commands 
even for data that relate to a single context. If the {cmd:contextvars} option is not specified, each of 
those individual commands treats the data as belonging to a single context.

{pstd}
The commands take a variety of options, as documented in individual help files, some with quite 
cumbersome names. However, ALL options can be abbreviated to their first three characters and many 
can be omitted (as documented).

{pstd}
The commands also save a variety of indicator variables (as documented). Most of these start with an 
underscore character and can be deleted by "drop _*" if the user does not want them to clutter a dataset. 
Three variables created by the command {help genstacks:genstacks} are needed by other tools and do not 
start with the underscore character. These are  genstacks_stack, genstacks_item and genstacks_nstacks.


{title:Workflow}, 

{pstd}
The {cmd:genstacks} command always operates on an unstacked dataset, reshaping it into stacked format. 
Other commands may operate on either stacked or unstacked data, except that {help genplace:{bf:genplace}} 
requires stacked data because the objects it locates in spatial terms are stacked batteries. No facility 
is provided for unstacking a previously stacked dataset (a crude way to do this would be to drop all 
stacks beyond the first).{break}

{pstd}The commands {cmd:gendist} and {cmd:genyhats} by default assume the data are 
stacked and treat each stack as a separate context to be taken into account along with any 
higher-level contexts. These commands can, however, be used on unstacked data or they can be directed to 
ignore the stacked structure of the data by specifying the {cmd:nostack} option. This option has no effect 
on {cmd:gendummies} or {cmd:genmeans} or on any StackMe command that is being used on unstacked data 
(since unstacked data have only one stack per case). With stacked data, ignoring the separate contexts 
represented by each stack might be considered desirable if prior analysis has established that there 
is no stack-specific heterogeneity relevant to the estimation model for which these transformations are 
being performed. Alternatively, the user might employ this option so as to impute a variable that is 
completely missing in one or more stacks (e.g. particular choices not asked regarding non-governing 
parties).{break} 

{pstd}For logical reasons some restrictions apply to the order in which commands can be issued. 
In particular:{p_end} 
{pmore}(1) {cmd:iimpute}, when used for its primary purpose of imputing (variance inflated) missing values 
for a battery of items, requires that data not be stacked, since members of that battery (eg. PTVs) are 
used to impute missing data for other members of the same battery; 

{pmore}(2) {cmd:gendist} can be useful in plugging missing data for items that can then be named in 
{cmd:iimpute}'s {bf:addvars} option to help in the imputation of missing data for other variables;

{pmore}(3) if {cmd:genyhats} or {cmd:gendist} commands are issued before stacking, they will have to be 
used once for each of the individual variables that will, after stacking, become a single (generic) 
variable (a workaround syntax has been created for genyhats that permits multiple batteries to be named 
on the same command line, and this syntax may be generalized in later releases to be used with other 
commands as well; but the {cmd:genyhats} command takes considerably longer to execute if issued before 
stacking; 

{pmore}(4) if {cmd:gendist} is employed after stacking, the items to which distances are computed 
have themselves to first have been reshaped into long format by stacking them; and finally

{pmore}
(5) after stacking and the generation of y-hat affinity variables, the number of variables required for 
a final (set of) {help mi:{bf:mi}} command(s) will generally be greatly reduced, cutting the time needed 
to perform multiple imputations for what are generally very large datasets (see SPECIAL NOTE ON MULTIPLE 
VERSUS SINGLE IMPUTATION in {bf:{help {iimpute:iimpute}}}.

{pstd}
Consequently, a typical workflow would involve using {cmd:iimpute} to fill out any batteries of 
conceptually-linked items by imputing any that might be missing, followed by {cmd:genstacks} to stack 
the data. This would often be followed by {cmd:genyhats}, used to transform indeps (those that will 
not be transformed into distance measures) into y-hat affinities for the stacked depvar. The {cmd:gendist} 
command would then be used to plug missing values on item location variables and generate distances to 
be used in a final (set of) {help mi:{bf:mi}} command(s) that would eliminate remaining missing data.{break} 

{pstd}
Considerable flexibility is available, however, to transform a dataset in any sequence thought 
appropriate, since any commands except for {cmd:genstacks} and {cmd:genplace} can be employed either 
before or after stacking ({cmd:genstacks} only before and {cmd:genplace} only after stacking).  
Moreover, the researcher can use the {cmd:nostack} option to force the production of distances, y-hats 
and missing data imputations that "average out" contextual differences by regarding all 
stacks (and perhaps also certain higher-level contexts) as a single context. This 
might be thought desirable after having established that there were no significant 
differences between these contexts in terms of the behavior of variables to be included 
in an estimation model. For example, country-year contexts are often collapsed into year 
contexts for (cross-section) time-series analyses and this happens automatically if the country 
id variable is omitted from the {bf:contextvars} option).


{pstd}
A NOTE ON VARIABLE NAMING CONVENTIONS AND VARIABLE LISTS: StackMe command lines expect variable batteries
to be named in two different ways depending on whether the command is issued before or after stacking. 
Before stacking, variables from batteries of questions, one battery question for each battery item (for 
instance regarding different political parties), are expected to all have the same stub-name, with 
numeric suffixes that run from 1 to the number of items in the battery. Users with variable batteries 
whose items have disperate names (or stubnames with alphabetic suffixes) will need to rename such variables 
before using StackMe commands. After stacking, those different variables become a single variable named 
by the stubname used before the data were reshaped. So what was a variable list (of battery items) before 
stacking becomes a single battery variable after stacking. Note that the {cmd:genstacks} command, which 
transforms variables from pre-stacked to post-stacked format, uses post-stacking conventions for variable 
names (implied pre-stacking names are derived internally). At a third stage resulting batteries may be 
characterized by the (weighted) mean values of their members, becoming battery placement variables with 
new names each of which reflects the entity being placed (in electoral studies, perhaps a parliament or 
government). The {cmd:genplace} command produces a variable label that records the origin of such a 
battery placement variable.{break}
    VARIABLE LISTS thus look different before stacking than after stacking. Additionally, StackMe 
commands provide two different ways to refer to stacked variables:{break}
(1) in a varlist of what originally were stubnames, accompanied by an optioned "reference" name (of the 
battery being placed or the variable from which distances are being calculated or the name to be given 
to y-hat affinities), as documented in the helpfiles for relevant StackMe commands. Alternatively,{break}
(2) in a series of lists, separated by || and each starting with the name of the reference variable 
followed by a colon (":"). The colon is, in turn, followed by a list of variables to be associated with 
that reference variable, as documented (and similar to conventions used elsewhere in Stata – e.g. Stata's 
{help mixed:{bf:mixed}} command). The two formats can be interspersed in the same varlist, as signalled 
by the presence or absence of a colon following the first name in a list, as documented.{break}
   

{title:Authors}

{pstd}
Lorenzo De Sio - European University Institute (now LUISS);{break}
Mark Franklin - European University Institute (now emeritus at Trinity College Connecticut);{break}
includes previous code and other contributions by Elias Dinas


{title:Citation}

{pstd}
If you use {bf:StackMe} in published work, please use the following citation:{break}
De Sio, L. and Franklin, M. (2011) "StackMe: A Stata package for analysis of multi-level data" 
(version 0.9), {it:Statistical Software Components}, Boston College Department of Economics.
