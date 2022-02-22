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
The {cmd:stackme} package is a collection of tools for the analysis of stacked data. In 
the academic subfield of electoral studies this type of analysis is also strongly related 
to the notion of PTVs (hence the original PTVTools package that evolved into StackMe); 
but specific StackMe commands are now mostly documented in more general terms to accommodate 
usage across all academic fields of study that employ hierarchical (multi-level) datasets. 
In electoral survey research, the PTV acronym refers to Propensities To Vote, batteries
of items concerning the self-reported probability that the respondent will {it:ever} 
vote for a specific political party, and intended as indicators of what Downs (1957) 
referred to as "electoral utilities" (van der Eijk et al., {it:Electoral Studies} 2006; van 
der Eijk and Franklin, {it:Elections and Voters}, Palgrave Macmillan 2009).{p_end}

{pstd}
Such analyses make rather special demands both on the data and on methods of analysis.{break}

{pstd}
Firstly, data {it:stacking} is usually involved, implying that - in Stata terminology - analysis 
may call for data in {it:long} rather than in {it:wide} format (see {help reshape:reshape}); 
and analysis may focus on {it:response}-level data rather than {it:respondent}-level data, 
with responses (at the lowest level of analysis) nested (stacked) within respondents. 
However, StackMe facilitates reshaping of a dataset with multiple contexts, (eg. countries)
each with possibly different numbers of items (eg. political parties) in the battery(ies) to be 
stacked (meaning that some items will have missing data for all cases in certain contexts, a 
structure that would be hard to accommodate without elaborating Stata's native commands). After 
stacking (reshaping), each respondent is represented by multiple rows in the data matrix, one 
for each response that, before stacking, was not entirely missing.{break}
   NOTE: In conventional comparative survey data (produced by, e.g, the European Social Survey 
or surveys collected and post-processed by the Comparative Study 
of Electoral Systems) a fair number of question batteries are largely empty so as to 
accommodate data from countries whose surveys had larger numbers of battery items (e.g. political 
parties). After reshaping such surveys produce large numbers of rows that are missing for all but  
respondents from a single (or very few) countries. StackMe avoids using up memory and filespace 
with rows that consist entirely of missing data due to such happenstances.{break}

{pstd}
Secondly, the dependent variable is usually generalized to accommodate multiple contexts. Thus, in
electoral studies conducted in one country, a researcher might study the sources of votes for a 
particular political party; but with multiple countries having different party systems that question 
would be reconceptualized in terms of votes for a {it:generic} party – {it:any} party: a question 
such as "why do parties receive electoral support?" Such reconcptualization involves moving up the 
ladder of conceptual generality, which also happens when "father" is viewed as a "family" member or 
"school" is reconceptualized as an "educational establishment" 
yielding comparability across contexts if these 
involve different party systems or family structures or educational systems, as is common. This also 
affects {it:independent} variables, which have to be specially treated: reformulated it terms of 
distances (proximities) or in terms of some other type of affinity, such as so-called {it:y-hats}, 
before they can be used in a stacked analysis. In this, ptv analysis resembles analysis of discrete 
choice models for which it serves as a substitute, dealing with directly-measured preferences 
(utilities) rather than deriving these from the analysis of choices made.


{title:Description}

{pstd}
The {cmd:StackMe} package includes the following commands:

{p2colset 5 20 22 2}{...}
{p2col :{bf:{help gendist:gendist}}}(Context-wise) generation of distances for batter(ies) of spatial 
items, after optionally plugging missing data on the spatial items{p_end}
{p2col :{bf:{help iimpute:iimpute}}}(Context-wise) incremental simple or multiple imputation of a 
set of variables{p_end}
{p2col :{bf:{help genstacks:genstacks}}}(Context-wise) reshaping of a dataset for PTV analysis{p_end}
{p2col :{bf:{help genyhats:genyhats}}}(Context-wise) generating {it:y-hat} affinity measures 
linking indepvars to ptvs{p_end}
{p2col :{bf:{help gendummies:gendummies}}}generates set(s) of dummy variables, with specific 
options{p_end}
{p2col :{bf:{help genmeans:genmeans}}}generates (optionally weighted) means of variables within 
contexts (similar to Stata's {cmd:egen} command with the {bf:by} option, but permitting calculation 
of weighted means){p_end}
{p2col :{bf:{help genplace:genplace}}}generates (optionally weighted) placements of (e.g.) political 
parties according to the (likely diverse) placements made by individual respondents, with option to 
weight those placements by the (weighted) number of respondents or by substantively meaningful 
weights{p_end}

{pstd}
These tools largely duplicate existing commands in Stata but operate on data with multiple contexts 
(eg. countries or country-years) each of which requires separate treatment. Moreover, all of the 
commands in {cmd:stackme} have additional features not readily duplicated with existing Stata commands 
even for data that relate to a single context. If the {cmd:contextvars} option is not specified, each of 
those individual tools treats the data as belonging to a single context.

{pstd}
The commands take a variety of options, as documented in individual help files, some with quite 
cumbersome names. However, ALL options can be abbreviated to their first three characters and many 
can be omitted (as documented).

{pstd}
The commands also save a variety of indicator variables (as documented). Most of these start with an 
underscore character and can be deleted by "drop _*" if the user does not want them to clutter a dataset. 
Three variables created by the command {help genstacks:genstacks} are needed by other tools and do not 
start with the underscore character. These are  genstacks_stack, genstacks_item and genstacks_nstacks.


{title:Workflow}

{pstd}
The {cmd:genstacks} command always operates on an unstacked dataset, reshaping it into stacked format. 
Other commands may operate either before or after stacking (generally both). No facility is provided for 
unstacking a previously stacked dataset (a crude way to do this would be to drop all stacks beyond the 
first).{break}

{pstd}The commands {cmd:gendist} {cmd:iimpute} {cmd:genplace} and {cmd:genyhats} by default assume the 
data are stacked and treat each stack as a separate context to be taken into account along with any 
higher-level contexts. These commands can, however, be used on unstacked data or they can be forced to 
ignore the stacked structure of the data by specifying the {cmd:nostack} option. This option has no effect 
on {cmd:gendummies} or {cmd:genmeans} or on any StackMe command that is being used on unstacked data (since 
unstacked data have only one stack per case). With stacked data the {cmd:nostack} option has the effect 
of making the command ignore the separate contexts represented by each stack. This might be considered 
desirable if prior analysis has established that there is no stack-specific heterogeneity relevant to the 
estimation model for which these operations are being conducted, or in order to impute a variable that is 
completely missing in one or more stacks (for example particular choice options that were not asked). 
Option {cmd:nostack} cannot be used with command {cmd:genplace}, which {it:must} be issued after stacking, 
since placement of item batteries assumes that the items are stacked into batteries so that those 
batteries can be placed.{break} 

{pstd}For logical reasons some restrictions apply to the order in which commands can be issued. 
In particular:{p_end} 
{pmore}(1) {cmd:iimpute}, when used for its primary purpose of imputing (variance inflated) missing values 
for a battery of items, requires that data not be stacked, since members of that battery (eg. PTVs) are 
used for the imputation of other members of the same battery; 

{pmore}(2) {cmd:gendist} can be useful for removing missing data from items that can then be named in 
{cmd:iimpute}'s {it:addvars} option to help {cmd:iimpute} missing data on other variables;

{pmore}(3) if {cmd:genyhats} or {cmd:gendist} commands are issued before stacking, they will have to be 
used once for each of the individual variables that will, after stacking, become a single (generic) 
variable (a workaround syntax has been created for genyhats that permits multiple batteries to be named 
on the same command line, and this syntax may be generalized in later releases to be used with other 
commands; but the {cmd:genyhats) command takes considerably longer to execute if issued before stacking); 

{pmore}(4) if {cmd:gendist} is employed after stacking, the items to which distances are computed 
have themselves to first have been reshaped into long format by stacking them; and finally

{pmore}
(5) after stacking and the generation of y-hat affinity variables, the number of variables required for 
a final (set of) {help mi:bf{mi}} command(s) will generally be greatly reduced, cutting the time needed for 
multiple imputation in what are generally very large datasets (see SPECIAL NOTE ON MULTIPLE VERSUS 
SINGLE IMPUTATION in {bf:{help {iimpute:iimpute}}}.

{pstd}
Consequently, a typical workflow would involve using {cmd:iimpute} to fill out a battery 
of PTVs by imputing any missing items, followed by {cmd:genstacks} to stack the data. This would often be 
followed by {cmd:genyhats}, used to transform indeps (those that will not be transformed into distance 
measures) into y-hat affinity measures linking these affinity indeps to the stacked depvar with whch the 
affinity is measured. The {cmd:gendist} 
command would then be used to plug missing values on item location variables and generate distances to 
be used in a final {help mi:{bf:mi}} command that would eliminate remaining missing data.{break} 

{pstd}
Considerable flexibility is available, however, to transform a dataset in any sequence thought 
appropriate, since any commands except for {cmd:genstacks} and {cmd:genplace} can be employed either 
before or after stacking ({cmd:genstacks} only befpre and {cmd:genplace} only after stacking).  
Moreover, the researcher can use the {cmd:nostack} option to force the production of y-hats that 
"average out" contextual differences by regarding all stacks (and perhaps also certain higher-level 
contexts) as a single context. This might be thought desirable after having established that there 
were no significant differences between these contexts in terms of the behavior of variables to be 
included in an estimation model (country-year contexts are often collapsed into year contexts for 
(cross-section) time-series analyses).


{title:Authors}

{pstd}
Lorenzo De Sio - European University Institute;{break}
Mark Franklin - European University Institute;{break}
includes previous code and other contributions by Elias Dinas


{title:Referencing}

{pstd}
If you use {bf:StackMe} in published work, please use the following citation:{break}
De Sio, L. and Franklin, M. (2011), StackMe: A Stata package for analysis of multi-level data 
(version 0.9), {it:Statistical Software Components}, Boston College Department of Economics.


NOTE: It might be desirable to optionally permit users to employ the elaborated variable 
list syntax designed for genyhats also in gendist; and to employ a varlist for gendummies.

