*! Feb18'26

{smcl}
{cmd:help StackMe}
{hline}

{p2colset 3 14 14 2}{...}
{p2col :{bf:StackMe} {hline 2}}package of Stata commands that pre-process and {help reshape} data 
in preparation for multi-level or hierarchical (sometimes known as contextual) analysis, often of 
survey data;  also providing an interface to other Stata commands that can be used to analyze the 
resulting data while taking advantage of {bf:stachMe}'s contextual awareness.           Adjust window size -->|  
   (This helpfile contains diagrams that can lose coherence if lines are shorter).{p_end}

{p2colreset}{...}

{marker Introduction}
{title:Introduction}

{pstd}
The {cmd:stackMe} package is a collection of software tools for generating and manipulating stacked 
{help reshape:(reshape}d) data. In the academic subfield of electoral studies, where StackMe was 
developed, reshaping is commonly employed to facilitate the analysis of multi-level (hierarchical)
data (see below). Indeed, use of {cmd:stackMe} is hardly called for with conventional datasets – even 
datasets containing multiple-response data, for which {cmd:reshape} is also used. The {bf:stackMe} package 
adds transparency and, above all, speed to operations involving hierarchical data; also helping the 
user to keep track of the plethora of variables needed to make the most of hierarchical analyses as  
well as significantly accelerating the generation and analysis of such variables in what are often 
very large datasets.{p_end}

{marker Quickstart}
{title:Quick Start}

{pstd}
This help file is quite verbose, aiming to provide an introduction to the operationalization of what, 
to some, may seem quite esoteric concepts using what, to others, might be somewhat impenetrable 
vocabulary (perhaps deriving from a different research tradition). If you already know what is meant 
by phrases like "question battery", "reshaping"/"stacking" "generic variable" and "affinity measure" 
you may want to dive right into the {bf:stackMe} commands that facilitate the creation/manipulation 
of such batteries and measures, using links provided in those commands' help files to clarify matters 
that remain obscure. This short paragraph introduces the one command needed to get started.{p_end}
{marker SMcontextvars}{...}
{pstd}{space 3}The {bf:stackMe} utility {help SMsetcontexts:{ul:SMset}contexts} provides other {bf:stackMe} 
commands with the most basic and essential information regarding the dataset currently in {bf:{help use}}: 
the names of variables (often {it:country} and {it:year}) that define its hierarchical structure (if any), 
thus:{p_end}

{pstd}{space 3}{cmdab:SMset:contexts} [ {varlist} ] [| , nocontexts ]{p_end}

{pstd}It is recommended that this utility be invoked immediately after {bf:{help use}}ing the datafile that 
will be processed by other {bf:stackMe} commands.{p_end}  
{pstd}Those other {bf:stackMe} commands are listed and briefly introduced in the {help stackme##Description:Description} 
section of this introductory helpfile. But first, for those taking the more leisurely approach, we need to 
introduce some foundational concepts and vocabulary.

{marker Datastacking}
{title:Data Stacking}

{pstd}
This often involves what are referred to as "batteries" of survey items, each of which asks 
the same survey question about each in turn of a number of conceptually-connected 
reference-items, often political parties. Each respondent to the survey provides a set of answers 
to each battery of questions, producing a corresponding battery of variables in the resulting 
dataset. If the same questions were asked about four political parties there would be four 
responses in each battery at the respondent level of analysis. This way of organizing 
the data is referred to by Stata as {help reshape:"wide"} format, as illustrated. 

              Wide     
    +-------------------------+         Wide-format layout of data regarding left-right positions 
    |  i  plr1 plr2 plr3 plr4 |         (plr) of four parties, identified by numeric suffixes 1-4 
    |-------------------------|         appended to the 'plr' stubs, for two respondents numbered 
    |  1   4.1  4.5  6.5 5.4  |         i=1 and i=2. And we see each of the four left-right party 
    |  2   3.3  3.0  4.4 4.0  |	        positions observed by each respondent as being "stacked",
    +-------------------------+         with i=1 responses positioned above the i=2 ones.

{pstd}
But, for many purposes (some of them detailed below), one might want a separate observation for each 
response, with the stacks of responses being themselves "stacked" on top of each other in what Stata 
refers to as "{help reshape:long}" format. Such "reshaping" increases the number of observations in 
the data (fourfold in this example) and changes the level of analysis from the respondent level to 
the response level, as shown below.

        Long         
    +–––––––––––+         Long format layout of the same data as shown above. Note how the numeric 
    | i  j  plr |         suffixes that had distinguished specific 'plr#' variables have morphed into
    |–––––––––––|         values of the new 'j' variable, and how 'plr' has lost its suffixes since,
    | 1  1  4.1 |         in long format, the values that had been assigned to successive wide-format
    | 1  2  4.5 |         substantive variables are now assigned to successive observations for the 
    | 1  3  6.5 |         one long-format substantive variable.
    | 1  4  5.4 |            Thinking of the four {bf:{it:plr}} columns in wide format as themselves being stacks 
    | 2  1  3.3 |         of observations, we might see the long-format {bf:{it:plr}} variable as being a sort 
    | 2  2  3.0 |         of "superstack" in which the wide-format {bf:{it:plr}}# variables have been interleaved
    | 2  3  4.4 |         across individual respondents identified by different i-values. In this 
    | 2  4  4.0 |         "stack of stacks" each j-value identifies the wide-format stack that had 
    +–––––––––––+         previously housed that same observation (why 'j' is called a "stack id").
                          
{pstd}
And note that the data-point concerned (for example the value 4.0, bottom right of each table) can be 
correctly called an "observation" in either format. The difference lies in who is making the observation 
– the reseacher who posed the question or the respondent who answered it. In wide format the focus is on 
the respondent and features of that respondent (in survey research, often the opinions of that respondent 
including their opinions regarding political parties, in our example). In long format the focus is on the 
items that respondents were asked about and features of those items (in the opinion of each respondent). But 
the survey is likely to ask about many topics beyond the battery items that will be stacked: features of 
the respondent, such as their age, gender, and level of education; and features of the situation in which 
respondents find themselves (such as the state of the economy). Such features do not vary across the
items being stacked (political parties in our example) so, if such variables are included in the reshaping 
operation that stacks the data, they will be constant across the observations relating to each party for 
each respondent. But, even if constant across battery items, those variables may still affect relationships 
between respondents and battery items (in a bad economy respondents may support different parties than they 
would in a good economy).

{pstd}
{bf:IT IS IMPORTANT} to keep track of whether a dataset is stacked or not and, if stacked, what is the 
"stack identification variable". In datasets stacked by {cmd:stackMe}'s {help genstacks:{ul:genst}acks} 
command, this variable is named {it:{cmd:SMstkid}} by default and it is recommended that this name not be 
changed. This variable, the `j' variable in the above description of stacked data, generally identifies 
the battery item that corresponds to each stack but, if it does not, then a variable must be created (if it 
does not already exist) that links stacks to batteries (for example, party identification number). It is 
recommended that such links between stack IDs and battery items be named by {cmdab:genst:acks}'s {opt ite:mname} 
option. The variable concerned will be added to the list of variables to be reshaped by {cmdab:genst:acks} 
so that the stacked counterpart can be used to define relevant linkages (for example when merging the stacked 
data with data from relevant archives). For a more detailed account of these linkage mechanisms see the 
{help stackme##stackmespecialnames:Special Names} section of this help text, below, and the help text for stackMe 
command {help genstacks:{ul:genst}acks}.{p_end} 
{pstd}
Data stacking is often employed in statistical analyses involving hierarchical or multi-level 
(sometimes known as contextual) data, as already mentioned. Indeed, {cmdab:genst:acks} is mainly 
useful in such contexts. With a conventional dataset from a single context, the standard Stata 
{help reshape} command would be just as appropriate and (possibly) a tad faster. For a more detailed 
walk-through of the logic of data-stacking see the {cmd:stackMe} help file named {help SMwriteYourOwn}.{p_end}

{pstd}
{bf:CRITICAL NOTE:} A dataset can only be stacked on the basis of one variable (a second variable 
can be added for doubly-stacked data). So a conventional dataset that contains batteries of variables 
organized in regard to more than one set of items (say batteries that ask the same question about each 
issue as well as batteries that ask about each party) can give rise to more than one stacked dataset 
(in this example) one stacked by party and a different one stacked by issue. Either of these stacked 
datasets could later be doubly-stacked with parties within issues (or issues within parties).{p_end}

{pstd}
Analysis of hierarchical data makes rather special demands both in terms of methods of analysis 
and in terms of the data being analysed. {cmd:StackMe} manipulates relevant data (often survey 
data) in a variety of ways to prepare it for ensuing hierarchical (multi-level) analyses, calling 
for user familiarity with a number of additional technical terms and conventions.{p_end}

{marker Terms}
{title:Terms and conventions}

{pstd}
{cmd:StackMe} facilitates the reshaping of a dataset with multiple contexts (e.g. countries)
each with possibly different numbers of items (e.g. political parties) in the battery(ies) to be 
stacked. Batteries that have different lengths (e.g. different numbers of political parties) in 
different contexts imply missing data for all observations in certain of those contexts.{p_end}
{pstd}
{space 3} {bf:Empty batteries:} In conventional comparative survey data (e.g. the European Social 
Survey or  surveys post-processed by the Comparative Study of Electoral Systems) a fair number of 
question batteries are largely empty so as to accommodate data from countries whose surveys had 
larger numbers of battery items (e.g. political parties). After reshaping, such surveys produce 
many observations that are entirely missing for all but respondents from a single (or a very few) 
countries. StackMe, by default, avoids burdoning execution time with evaluations of rows that consist 
entirely of missing data due to such happenstances.{break}
{space 3} {bf:Battery boundaries} also have a number of implications relevant to the handling of 
{it:hierarchical data}. These arise because batteries of variables often have interrelationships 
(typically negative inter-correlations due to patterns in respondent preferences – for example 
preferences for political parties). Such patterns can affect multivariate analyses of any kind. 
For example, multivariate analyses are at the heart of imputation estimations which may be 
deliberately performed using unstacked data in order to take advantage of within-battery 
interrelationships when plugging observations for which answers to battery questions are absent.{break}
{space 3} {bf:Units and items} The malleability of data in terms of wide versus long format gives 
rise to ambiguity when referring to "observations", a word that changes its meaning with changes 
in the level of analysis. In {cmd:stackMe} we use the word "unit" to refer specifically to 
observations at the original level of analysis, before stacking, and the word "item" to refer 
specifically to the battery item that will become an observation after stacking.{p_end}

{marker Genericvariable}{marker Affinitymeasures}
{title:Generic variable analysis and affinity measures}

{pstd}
Critically, the dependent (outcome) variable is usually generalized to accommodate multiple contexts. 
So while in electoral studies conducted in one country a scholar might seek to answer a research 
question such as "why do people vote for the Liberal party?", with multiple countries having different 
party systems that question will generally need to be reconceptualized in terms of votes for a 
{it:generic} party – {it:any} party – with a research question like "what explains the level of electoral 
support that a party receives?" (Thus "voting for party A" becomes "voting for a party") Such 
reconceptualization involves moving up the ladder of conceptual generality, which also happens when 
"Sun-Times" is viewed as a "newspaper" or "Lincoln High" is viewed as a "school".  Such reconceptualizations 
produce comparability across contexts if these involve different party systems or media structures or 
educational systems, as is common. More importantly, the more general conceptualization inevitably results 
in more generally applicable explanations of social phenomena – what many would say is the primary benefit 
of comparative socio-political studies. But these more general explanations also require a more generic 
formulation of {it:independent} variables (sometimes called {it:input} variables) which must be reformulated 
to focus on the process or mechanism that brings the two together, often referred to as the "affinity" that 
an indep shows for a depvar.

    +–––––––––––––––––––––––––––+
    | i  j  plr  rlr  dlr  prox |         Deriving proximity as a measure of affinity between
    |–––––––––––––––––––––––––––|         voters and parties in left-right terms. Variable plr
    | 1  1  4.1  2.2  1.9  8.1  |         is the same variable used earlier; rlr is respondent's 
    | 1  2  4.5  2.2  2.4  7.6  |         left-right position; dlr is the distance between rlr 
    | 2  1  3.3  6.5  2.3  7.5. |         and plr on a 10-point scale. Proximity, the final 
    | 2  2  3.0  6.5  4.2  5.8. |         variable, is inverse distance (10 - dlr), a measure of 
    +–––––––––––––––––––––––––––+         affinity between voters and parties in left-right terms.

{pstd}
{cmd:StackMe} generates three measures of affinity: proximities – inverted distances as shown above (see 
command {help gendist:{ul:gendi}st}) – and, for non-spatial items, either dummy variables (e.g. "this is 
the party this respondent voted for", "this is the party this responded feels close to" – see command 
{help gendummies:{ul:gendum}mies}) or so-called {it:y-hat}s (see command {help genyhats:{ul:genyh}ats}). 
Easing the construction of such affinity measures was originally intended to encourage research employing 
PTV (for Propensity To Vote) measures, derived from survey data, as a substitute for discrete choice 
modeling from analysis of choices made (van der Eijk et al., 2006). But analysis of discrete choice data 
can benefit just as much from many of the facilities that {cmd:StackMe} provides.{break}
{space 3}A primary objective of {cmd:StackMe}'s {help genplace:{ul:genpl}ace} command is to provide links 
to other {bf:Stata} commands, such as {help factor} and {help MCA}, that already provide the functional 
equivalent of affinity measures. Those linkage facilities also permit user-written contributions to {bf:stackMe} 
of pretty much any kind, some of which may further increase the number of ways in which affinities can be 
measured. For more about adding user-written programs to {cmd:stackMe} see the help texts for 
{help genplace:{ul:genpl}ace} and {help SMwriteyourown:{ul:SMwri}teYourOwn}.{break}

{pstd}
Most of the above affinity measures bring with them limitations often linked with some degree of controversy 
regarding their theoretical or methodologica underpinnings. But {help gendummies} engenders no controversy 
and its major limitation (the fact that a numerical variable will have to be divided into categories of 
increasing magnitude) is well-understood and non-controversial. It is a "lowest common denominator" fallback 
for operationalizing an affinity measure based on any sort of data.

{marker Doublystackeddata}
{title:Doubly-stacked data}

{pstd}
This type of datastructure is relevant to the analysis of hierarchical (multi-level) data in any 
discipline; but we introduce the concept with benefit of an example from our own subfield. In 
electoral studies, as well as batteries of party-related questions, there can also be batteries 
of issue-related questions. Issues are of relevance not only to respondents (who often have issue 
preferences that vary across issues) but also to parties (that often take different positions in 
regard to different issues). Issue batteries can be stacked either within parties or within respondents; 
but if they are stacked within parties that are already stacked within respondents then the data 
become doubly-stacked and the stacking of issues within parties within respondents can be used 
to link parties to respondents via the issues that both have in common, facilitating studies 
of issue-based party choice.{p_end}

{marker Affinitymeasures}
{title:Affinity measures in doubly-stacked data}

{pstd}
There are no established procedures for handling affinities in doubly-stacked data, so anyone wanting 
to attack this frontier of research in their own academic discipline is free to design their own approach, 
perhaps helped by the examples provided of our own approach to doubly-stacked data in the subfield of 
electoral studies. As already mentioned, these examples take the form of "user-written programs" that 
can be "hung" onto "hooks" that we have provided, in {cmd:StackMe}'s {help genplace:{ul:genpl}ace} 
command, designed to facilitate the incorporation into {cmd:stackMe} of new code that operationalizes 
whatever new insights may arise. See the help texts for {help SMwriteyourown:{ul:SMwri}teYourOwn} for 
details.{p_end}

{marker Programefficiency}
{title:Program efficiency}

{pstd}
Multi-level comparative datasets constructed from survey data across multiple countries over 
increasingly lengthy spans of time can be huge. Standard data analysis procedures with such data 
can be very time-consuming. For one-off estimation analyses those costs must be born, but for 
data management tasks that will be repeated multiple times it is worth taking the trouble to come 
up with (and learn to benefit from) procedures that maximize Stata's strengths, even at the cost 
of heavy outlays of time for program-design and coding. Such programming efforts give rise to 
suites of Stata commands such as the package documented here. {cmd:StackMe} has been operationalized 
on the basis of extensive experimentation to minimizing processing time especially for operations 
that will need to be repeated for a large proportion of variables in a survey-based dataset. The 
syntax innovations adopted for {cmd:StackMe} commands are designed to facilite the processing of 
as many variables as possible on a single pass through the data, permitting programming strategies 
that minimize execution time.{p_end}

{marker Description}
{title:Description}

{pstd}
The {cmd:stackMe} package includes the following commands, all of which can be abbreviated to their 
first five characters (but longer abbreviations are not allowed):

{p2colset 5 17 15 2}{...}
{p2col:{ul:Commands primarily intended to prepare data for stacking}}{p_end}

{p2col :{help stackme##SMsetcontexts:{ul:SMset}contexts}} establishment, within the datafile currently in 
{help use}, of a 'data characteristic' for the benefit of other {bf:stackMe} commands that either identifies 
the dataset as a standard Stata .dta file, without distinctions between contexts, or provides a 
list of the variables that will define that dataset's contexts (e.g. {it:country} and {it:year}). The data 
in the file should not already be in stacked (in what Stata calls 'long') format when its contexts are 
defined.{p_end}
{p2col :{help gendummies:{ul:gendu}mmies}}generation of set(s) of dummy variables, each set encompassing the 
values (Stata sometimes refers to these as "levels") of a categorical variable whose name, by default, 
becomes the textual stub for the name of each outcome dummy variable in the set. These outcomes can also 
be seen as sets of indicator variables that take the value 1 for observations with the value indicated by 
the suffix to that indicator and zero otherwise. So a categorical variable named {it:gender} taking on 
values of 0 for males and 1 for females will produce two outcome dummies named {it:gender0} and {it:gender1} 
for which each observation will be coded 1 if that observation has the input value of the suffix and 0 
otherwise. This is very unlike Stata's {help tabulate} command (with the {opt generate} option) that would 
produce two variables named {it:gender1} and {it:gender2} whatever two values were found in the data. And, 
unlike Stata's {help indicator} variables, these dummy variables will actually exist in the dataset, once 
defined, making them amenable to stacking (which indicator variables are not). See 
{help gendummies:{bf:{ul:gendu}mmies}} for details.{p_end}
{p2col :{help geniimpute:{ul:genii}mpute}}(Context-wise) incremental simple or multiple imputation of 
missing data within a set of variables, taking advantage of within-set interrelationships if the data are 
not yet stacked (see {help geniimpute:{bf:{ul:genii}mute}} for details. The second "i" in "iimpute" stands 
for "inflated" as, by default, imputed values are inflated using random perturbations that permit 
iimputed data for multiple contexts to substitute for multiply-imputed datasets as employed by Stata's 
{bf:{help mi:mi}} suite of commands – data for which the "mutiple" in "multiply-imputed" is obtained by 
duplicating the original observations as many times as needed while adding random perturbations to 
observations whose missing data have been plugged.{p_end}{p2col :{help gendist:{ul:gendi}st}}(Context-wise) 
generation of distances between spatially-located self-placement variables and each member of a 
corresponding battery of spatial items (e.g. political parties), with customizable treatment of missing data. 
It makes no difference to the results whether this command is issued before or after stacking.{p_end}
{p2col :{help genyhats:{ul:genyh}ats}}(Context-wise) generation of {it:y-hat} 
{help stackme##Genericvariable:affinity measures} that can facilitate {help genstacks##Genericvariable:generic} 
variable analysis in stacked data. Such variables can be generated either before or after stacking. But, 
for both {help gendist:{ul:gendi}st} and {help genyhats:{ul:genyh}ats} it will generally be more economical 
to generate the resulting measures after stacking. But the order in which these two commands are employed 
(in relation to each other and in relation to command {help genstacks:{ul:genst}acks}) could matter in ways 
that, to the best of our knowlede, have not yet been fully investigated. See under the heading 
{help stackme##Workflow:Workflow}, below, for some relevant considerations.{p_end}

{p2col:{ul:Stacking command}}{p_end}

{p2col :{help genstacks:{ul:genst}acks}}(Context-specific) reshaping of a dataset for response-level 
analysis (see the relevant introductory {help stackme##Datastacking:paragraph} above). No facility is 
provided for unstacking a previously stacked dataset (a crude way to do this would be to {help keep} 
just a single stack for every original observation). So it is strongly recommended that users create 
and save a dofile containing the Stata code responsible for prepping and stacking the original Stata 
data file. ({bf:NOTE} that the original data file may give rise to more than one stacked dataset, if 
the original dataset contains question batteries relating to more than one set of reference items – 
for example batteries related to issues (one question per battery for each issue) as well as batteries 
related to parties (one question per battery for each party).{p_end}

{p2col:{ul:Commands primarily intended for use with stackd data}}{p_end}

{p2col :{help SMitemnames:{ul:SMite}mnames}} names, within the datafile currently in {help use}, 
two more 'data characteristics' (complementary to the 'contextvars' characteristic documented at the 
top of this list of {cmd:stackMe} commands). These can (re-)define the linkage variables (named 
{it:{bf:SMitem}} and {it:{bf:S2item}}) described in {help stackme##stackmespecialnames:Special Names} 
later in this helpfile. Those SM names serve as aliases to variables that can supplement {it:{bf:SMstkid}} 
and {it:{bf:S2stkid}} in identifying the different stacks created by {help genstacks:{ul:genst}acks}.{p_end}
{p2col :{help SMfilename:{ul:SMfil}ename}}{...} corrects the name of the datafile currently in use, if that 
name somehow no longer matches the actual name of that file. Generally these names are updated automatically 
as a file morphs from original to stacked to {help stackme##Doublystacked:doubly-stacked} status (or 
as users rename or move a file to a different directory within the computer's file structure); but things 
can go wrong and this utility program would be used to fix any filename glitches.{p_end}
{p2col :{help SMorigin:{ul:SMori}gin}}{...} provides a list of variables each of whose labels is to be 
individually elaborated into an "origin story" naming the variables that were its precursors as it was 
processed successively by, for example, {opt genii:mpute} -> {opt gendi:st} -> {opt genyh:ats}. Note that 
{cmd:stackMe}-generated variables already receive labels that record the operation producing each new 
outcome. A {help SMorigin:{ul:SMori}gin}-generated label simply elaborates each of these descriptions into 
a summary historical record (losing some detail in the process).{p_end}
{p2col :{help genmeanstats:{ul:genme}anstats}}generates (optionally weighted) variable means, 
and other mean-related statistics, separately within contexts – similar to Stata's {help egen} command 
with the {bf:by} option but permitting the statistics to be appropriately weighted, which the above 
alternative does not. Command {help genmeanstats:{ul:genme}anstats} can optionally be 'call'ed from within 
command {cmdab: genpl:ace} (below) if objects are to be placed on grounds other than mean values.{p_end}
{p2col :{help genplace:{ul:genpl}ace}}generates placements at the battery-level that will characterize 
battery items in terms of unit-level characteristics (placing e.g. political parties in terms of the 
characteristics of respondents who vote for those parties). At a higher level {cmdab:genpl:ace} can place 
higher-level objects, such as governments, in terms of battery-level characteristics (for instance 
locations in left-right terms of the parties that are members of a government). Placements can optionally 
be weighted by the (weighted) number of respondents and/or by substantively meaningful weights (e.g. 
proportions of seats or of ministries controlled by parties that are members of a government).{p_end}

{pstd}{cmdab:genpl:ace} also serves as an {it:interface} for existing Stata or user-written commands 
that can generate additional or alternative variables for placing battery items (or batteries seen as 
concepts/ entities in themselves). Thus {help factor} or {help MCA} analysis can generate scores that are 
distiguished by context, and affinity measures can be constructed from the results of context-dependent 
transformations and estimation procedures. Two examples of user-written commands are supplied that focus 
on the second of these objectives. One of them calculates a {it:polarisation} measure for stacked 
parties; the other generates {it:Issue Yield Index} values for battery items such as political parties 
(De Sio and Webber 2014). See help {help SMwriteYourOwn} for details. User programs are not limited to 
those that 'place' higher-level variables in terms of lower-level characteristics but may perform any 
sort of transformation that involves the variables listed in a {cmdab:genpl:ace} command (which can 
also hold the user-chosen options for that command). See {help genplace:{ul:genpl}ace} and the helpfile 
named {help SMwriteYourOwn} fordetails.{p_end}

{pstd}
The functionality of these tools can largely be emulated using existing Stata commands but this would in 
many instances require multiple steps (or call for advanced programing skills) in order to operate on data 
with multiple contexts (eg. countries or country-years), for each of which the data may need to be separately 
pre-processed or otherwise manipulated. Moreover, many of the commands in {cmd:StackMe} have additional 
features – especially speed of execution – not readily emulated when using existing Stata commands.{p_end}

{pstd}
The commands take a variety of {help options}, as documented in individual help files, some with quite 
cumbersome names. However, all options can be abbreviated to their first three characters (except that 
negating an option, where allowed, requires the letters "no" to precede those three characters, resulting 
in five-character minimum abbreviations – the same length as applies to {cmd:stackMe} command-name abbreviations).
But most options have default settings that can be accepted by simply omitting the option (as documented).{p_end}

{pstd}
The commands save a variety of indicators and measures, most of them being given {varname}s based on the 
names of the variable(s) from which they are derived (as documented). Three variables created by the command
{help genstacks:{ul:genst}acks} are needed by other {cmd:StackMe} commands and should not be deleted or have 
their names changed. These {help special names} are {it:{cmd:SMstkid}} (the stack identifier), {it:{cmd:SMnstks}} 
(the largest number of stacks, some of which might be all-missing and thus completely absent in certain 
contexts) and {it:{cmd:SMunit}}, the sequential id enumerating all original observations over all contexts. 
Additionally, command {help genstacks:{ul:genst}acks} takes note of a user-defined {cmd:item name}, 
as an alternative stack identifier (if there is such) which it records in any dataset stacked by 
{help genstacks:{ul:genst}acks} under an additional special varname: {it:{cmd:SMitem}}. For details see 
below under the heading {help stackme##stackmespecialnames:Special names}.


{marker Workflow}
{title:Workflow}

{pstd}
The {help genstacks:{ul:genst}acks} command normally operates on an unstacked dataset, {help reshape}ing it into 
stacked format (but it may also be used to {help stackme##Doublystackeddata:doubly-stack} an already stacked 
dataset). Other commands may operate on either stacked or unstacked data, except that command {help genplace:{ul:genpl}ace} 
requires stacked data because the objects this command {it:place}s (in spatial terms) or {it:codes} (in terms of 
other attributes) consist of stacked batteries.{break}

{pstd}Although having design features that separate commands into the three categories distinguished above, all 
commands in the first list may be used with either stacked or unstacked data. But, as already mentioned, command 
{help genplace:{ul:genpl}ace} makes no sense with unstacked data; and command {help genmeans:{ul:genme}ans} has very 
limited functionality in datasets that have not been stacked. Other commands, when used with stacked data, can be 
directed to ignore the stacked structure of the data and/or its contextual specificity by employing the {opt nosta:cks} 
and/or {opt nocon:texts} options, although these options have no effect on {help gendummies:{ul:gendu}mmies} which 
always operates at the level of analysis at which its {varlist} variables were defined or generated.{break}

{pstd}With stacked data, ignoring the separate contexts represented by each stack might make sense if exploratory 
analyses had established that there is no stack-specific heterogeneity relevant to the estimation models for which 
the data are being pre-processed. Alternatively, the user might employ the {opt nosta:cks} option so as to 
{help geniimpute:{ul:genii}mpute} plugging values for a variable that is completely missing in one or more stacks 
(e.g. resulting from particular alternatives that were not asked about for certain parties). The same considerations 
might justify the use of the {opt nocon:text} option in appropriate circumstances.{break}

{pstd}For logical reasons some restrictions apply to the order in which commands can be issued. In particular:{p_end} 
{pmore}(1) {help geniimpute:{ul:genii}mpute}, when used for its primary purpose of imputing (variance-inflated) 
plugging values (for use in plugging values that are missing in a battery of items) requires the data to {bf:not} be 
stacked, since items in each battery (e.g. party placements) are used to impute missing data for other members of the 
same battery while taking advantage of the negative correlations expected between members of the same battery; 

{pmore}(2) {help gendist:{ul:gendi}st} can be useful for plugging missing data for items that can then be named 
in {help geniimpute:{ul:genii}mpute}'s {opt add:vars} option to help in the imputation of missing data for other 
variables;

{pmore}(3) if {help gendist:{ul:gendi}st} is employed after stacking, the reference items from which distances 
are generated have themselves to have first been {help reshape}d into long format by including them among the 
variables to be stacked; and, finally,

{pmore}
(4) After stacking and the generation of y-hat affinity variables, the number of variables required for 
a final (set of) {help geniimpute:{ul:genii}mpute} command(s) will generally be greatly reduced, cutting the time 
needed to perform missing data imputations for what are often very large datasets.

{pmore}{bf:NOTE that processing time can be greatly reduced by grouping together all (pipe-delimited) {varlist}}s 
that can be processed by a single stackMe command under control of a single set of {it:{help options}}. This is a 
general feature of {cmd:StackMe} commands (see below under {help stackme##Variablelists:Variable lists}) although 
the effect is most evident with {help geniimpute:{ul:genii}mpute} and {help genyhats:{ul:genyh}ats} – the two 
{cmd:StackMe} commands that make greatest demands on processing power because they are generally employed to 
pre-process such a large proportion of the variables in a stacked dataset. (The {help genstacks:{ul:genst}acks} 
command has also been greatly accellerated, but using a different programing strategy.){p_end}

{pstd}
Consequently, a typical workflow would involve using {help gendist:{ul:gendi}st} to (optionally) plug missing values 
on item location variables and generate distance measures (each one such measure reducing dataset size by replacing 
its two constituent measures), followed by {help geniimpute:{ul:genii}mpute} to fill out remaining missing data in 
batteries of conceptually-linked items by plugging their missing values, and {help genyhats:{ul:genyh}ats} to 
transform indeps (those not already rendered tractable by being transformed into dummy variables or distance measures) 
into y-hat {help stackme##Affinitymeasures:affinities} with the stacked depvar. Then command {help genstacks:{ul:genst}acks} 
would be used to {help reshape} the data. The results might then be used in a final {help geniimpute:{ul:genii}mpute} 
(with multiple {varlist}s) operation to cull remaining missing data (Stata's {help mi:{bf:mi}} command(s) might be viewed 
as alternatives; but see the section on {bf:multiple imputation} in the help file for {help geniimpute:{ul:genii}mpute}).{p_end} 
{pstd}
Considerable flexibility is available to transform a dataset in any sequence thought appropriate, since any commands 
except for {help genstacks:{ul:genst}acks} and {help genplace:{ul:genpl}ace} can be employed either before or after 
stacking ({cmd:genstacks} can be used to "{stackme##Doublystackeddata:doubly-stack}" an already stacked dataset). 
Moreover, the researcher can use the {opt nos:tacks} and {opt noc:ontexts} options to force the production of distances, 
y-hats and missing data imputations that "average out" contextual differences by regarding all stacks (and perhaps also 
certain higher-level contexts) as a single context. This might make sense after preliminary analyses had established 
that there were no significant differences between these contexts in terms of the behavior of variables to be included 
in an estimation model.{p_end}

{pstd}
{bf:IMPORTANT NOTE ON KEEPING TRACK OF CONTEXTUAL DIFFERENCES} While country-year contexts are often collapsed into 
year contexts for (cross-section) time-series analyses and this might call for a (temporary) {opt con:textvars} option 
on a relevant {cmdab:genii:mpute} command (possibly for other {cmd:stackMe} commands as well), this sort of implicit 
collapsing of contextual differences should generally not be optioned in a {cmdab:stackme} command. Users can use the 
Stata {help collapse} command, after {help preserve}ng the pre-processed data, in time for specific Stata estimation 
commands. For these, panel variables can be specified as needed for relevant estimation commands (such as Stata's 
{help xt} commands or {help mixed} command) without affecting the underlying data. The pre-processed data can 
then be {help restore}d and employed to estimate other models without re-stacking.{break}
{space 3}{bf:USER BEWARE:} most {cmd:stackeMe} commands themselves {help preserve} the data for each context in turn 
and thus cannot be employed on data that the user has previously {help preserve}d.{p_end}


{marker Variablenaming}
{title:Variable naming conventions} 

{pstd}
{cmd:StackMe commands expect battery variables to be named} in one of two different ways. Before stacking, 
variables from batteries of questions, one battery question for each battery item (for instance regarding 
different political parties), are expected to all have the same stub-name, with numeric suffixes that generally 
run from 1 to the number of items in the battery (parties that were asked about). Users with variable 
batteries whose items have disperate names (or stubnames with alphabetic suffixes) will need to rename such 
variables before using the {help genstacks:{ul:genst}acks} command (see help {help rename group} especially 
rule 17).{break}
{space 3}{bf:After stacking, each battery of variables} becomes a single ({help reshape}d) variable named with the 
stubname that was used in the names of member items before stacking (see the section on 
{help stackme##datastacking:data stacking}, 
earlier in this help text). Note that, while the {help genstacks:{ul:genst}acks} command will accept {varlist}s 
of variables named in either fashion, using post-stacking {it:stubname}s for that command requires less typing 
and is more likely to avoid common naming errors.{break}
{space 3}{bf:All other variables generated by stackMe commands} are distinguished by having names that are 
prefixed with (by default) a two-character string separated by an underline character from the remainder of 
the variable name), as will be explained.p_end}


{marker Variablelists}
{title:Variable lists and option lists}

{pstd}
Every StackMe command name should be followed by a Stata {varlist} ({help genstacks:{ul:genst}acks} has a 
{it:{help namelist}} (of stub-names) alternative, as already mentioned) naming the variable(s) to be pre-processed 
by the command concerned. Each of these commands additionally offers an alternative {varlist} format that permits variables 
to be grouped into batteries (or quasi-batteries) by use of so-called "pipes" ({bf:"||"}) that separate the variables 
belonging to each (quasi-)battery. Where appropriate, each battery can be associated with a prefix (a {varname} or, where 
appropriate, a {varlist}) suffixed by a colon that preceeds the {varlist} proper. (More about prefix variables below). 
This (set of) varlist(s) will generally be associated with an {it:{help option}}list, for example:{p_end}

{p 5 14}
{opt gendi:st} [{help varname:selfplace}:] {varlist} {ifin} {weight} || [{help varname:selfplace}:] {varlist} {weight} ... || {break}
[{help varname:selfplace}:] {varlist} {weight}, {help options}{p_end}

{pstd}
Note that stackMe varlists improve on standard Stata varlists in being able to contain mixtures of hyphenated lists 
and single variables (combinations that risk producing syntax errors with standard Stata varlists). StackMe 
processes its own varlists, avoiding the risk of such irritations.{p_end}

{pstd}
The {ifin} expressions that can optionally follow a Stata {varlist} must, for {cmd:stackMe} commands, be placed following 
the first {varlist} in any set of varlists; the {weight} expression may follow any or all {varlist}s in a set 
of {varlist}s. The ', {it:{help option}}s-list', that generally follows the 'varlist [if][in][weight] component of a 
standard Stata command-line, on {cmd:stackMe} command-lines should follow the last of any such components.{p_end}


{marker:prefixes}
{title: Prefix strings and prefix variables}

{pstd}
Most generated (outcome) variables are given names by {cmd:stackMe} commands that derive from the names of existing 
(input) variables, processed in some fashion so as to yield the newly generated measures. The original variable names 
are sometimes used as 'stubs' (in commands {help gendummies:{ul:gendu}mmies} and {help genstacks:{ul:genst}acks}) 
obtained by stripping numeric suffixes from the names of variables to be processed. Such stubs firmly link the 
outcome variable names to the names of processed inputs; but with many {bf:stackMe} commands several outcome variables 
derive from the same input. To distinguish the several outcomes from each other {cmd:stackMe} outcome variables use 
'prefix strings' – two-character strings separated from the prefixed name by an underscore character ("_"). So 
{help gendist:{ul:gendi}st} uses the character string "dm_" to prefix the names of variables that indicate the original 
"missingness" of critical inputs, "dp_" to prefix the names of variables used for 'plugging' (filling in the holes left 
by those missing observations) and  "dd_" to prefix the names of  outcome variables holding the distance measures that 
give the command its name.{p_end}
{pstd}
{space 3}As should be evident, some of these prefix strings identify not the outcome of the command but an intermediate 
result: a variable employed in the process of generating the outcome that is treated as a quasi-outcome, of possible 
utility to the user of the command, who is given the choice of whether to keep it or not.{p_end}
{pstd}
{space 3}Not only strings serve as prefixes to variables but also variables can prefix other variables, going beyond 
supplying stubnames, as mentioned above. Variables as prefixes can provide an additional input needed to produce the 
desired outcome. Such prefix variables can be attached to the front of several {cmd:stackMe} commands' variable lists, 
set off by a colon from the {varlist} proper, as was illustrated using a {cmdab:gendi:st} example a few lines above.{p_end}
{pstd}
{space 3}Such prefix variables can take the place of certain optioned input variables when {bf:stackMe} commands employ 
multiple pipe-delimited varlists in the manner also described above. Recall that {cmd:stackMe} has as one of its main 
objectives the speeding-up of command execution by processing as many {varlist}s as possible on a single pass through 
the data. This is facilitated by keeping the same options in effect over multiple variable lists. Prefix variables 
can be seen as a sleight-of-hand; a way to circumvent what would otherwise have been a debilitating inability, with 
successive {varlist}s, to update variable choices that would have called for use of a now unavailable option.{break}
{space 3}Going further, in command {cmdab:genyh:ats}, the appearance of a prefix variable, or not, can signal whether 
the requested estimation process is multivariate or bivariate, so removing the need to update the relevant option and 
permitting additional varlist(s) to be processed on the same pass through the data. Details can be found in help-files 
named for the relevant commands.{p_end}
{pstd}
{space 3}When prefix variables are employed – a var-prefix or a stubname – these can themselves be prefixed by a  
prefix-string. The string that prefixes a prefix variable signals a change in the name of that variable, which will now 
be prefixed by that new string, differentiating between different versions of an outcome variable whose names would 
otherwise have been the same, halting execution. So we can get names like {it:class_vote} and {it:religious_vote}, which 
might also be preferred for aesthetic reasons. Such syntax variations bring opportunities for syntax errors, but {bf:stackMe} 
commands go to considerable lengths to anticipate name clashes and avoid having a command run to completion before 
detecting an error that would vitiate the time saved by such a command.{p_end}
{pstd}
{space 3}NOTE that the time saved through the use of judiciously chosen prefix strings is not just execution time for 
the {cmd:stackMe} command concerned but, often more importantly, user time that would otherwise be spent renameing 
outcome variables produced by one command before issuing another command involving the same variables.{p_end}

{pstd}{bf:DETERMINING WHICH OPTIONS CAN BE OVERRIDEN BY PREFIX VARIABLES} has been made as easy as possible. In the helpfile 
for any command that permits the use of prefixvars (all commands except {cmdab:genst:acks} and {cmdab:genme:anstats}) 
the option that can be replaced by a prefixing list of variables (stubs in the case of {cmdab:gendu:mmies}) is the 
first option listed in any list of available options. So a quick glance at the command's helpfile will be all that 
is needed to verify which option is the one concerned (in {cmdab:genpl:ace} it can be either of the first two options 
listed, as determined by the third option).{p_end}

{pstd}{bf:CUMULATING PREFIX STRINGS} are an inevitable feature of the {bf:stackMe} {help stackme##Workflow:Workflow} 
described earlier, along with the use made of prefix strings to distinguish between variables generated by different 
{bf:stackMe} commands. So a variable named "yi_ii_stk_dd_ii_vote" would have followed the {help stackme##Workflow:Workflow} 
pattern suggested in an earlier section. It builds on a measure of vote choice by, first, imputing missing data among 
battery members, then measuring reported distances between party placements and respondent self-placements, then 
stacking the resulting measure and moving on to conduct a second set of imputations on the stacked data before 
calculating a battery of yhat measures of affinity between independent variables and an optioned depvar.


{marker stackmespecialnames}
{title:stackMe special names}

{pstd}
Several "special names" are employed for variables generated by {cmd:stackMe}. These names should be avoided when 
picking names for substantive variables within a dataset that will be processed by {cmd:stackMe}. Some of these 
are names reserved for variables added to datasets that have been reshaped by the {cmdab:genst:acks} command. A 
"special prefix" modifies the name of a stacked dataset to flag the fact that the data have been stacked. These 
names are as follows:{p_end}

{p 4 10} 
{bf:SMunit} The {it:observation number} (or 'i' variable described in Stata's {help reshape} command). This variable 
is identical to the value of the Stata system variable {help _n} when not associated with {help by}). In survey 
research each observation will generally have been given a {it:respondent id number} that might be identical to 
{it:{cmd:SMunit}} but the presence or absence of such a respondent ID is ignored and unaffected by {cmd:stackMe} 
commands.{p_end}

{p 4 10} 
{bf:SMstkid} The {it:stack identifier} (or 'j' variable described in Stata's {help reshape} command) identifies 
each of what were members of a battery of integer-suffixed stub-names. If those suffixes were sequential numbers 
starting with '1' for the first suffix, values of SMstkid may match the original suffix-values but some values 
in the unstacked sequence can be absent from the stacked sequence for particular contexts if those values were 
completely missing from that context.{p_end}

{p 4 10}
{bf:SMnstks} The {it:{bf:maximum} number of stacks}, constant across units within stacks, found for {it:{bf}}any 
context.{p_end}

{p 4 10}
{bf:SMitem} An alias for the name of an already existing variable that provides an alternative link to battery-specific 
items, complementary to the link provided by SMstkid. This alternative link is often used to identify the value labels 
associated with specific levels (values) that were battery items before stacking (e.g. party names). This user-supplied
linkage variable is named using option {cmdab:ite:mname}. This "special name" can be used as an alternative to the 
variable's original name in stacked data. Used as an alias in this way, it may not be abbreviated.{p_end}

{p 4 10}
{bf:STKD} (and {bf:stkd}) The upper-case version of this prefix, plus an underscore to delimit the end of the prefix,  
is tacked on to the front of the filename of any dataset that is reshaped by {help genstacks}. Any variable stacked by 
{cmdab:genst:acks} has the lower-case version of this prefix tacked on to the front of its {bf:variable label}, followed 
by a space to delimit the end of the prefix.{p_end}

{p 4 10}
{bf:NOTE:} Further variables with special names are added by command {help genstacks:{ul:genst}acks} when producing 
doubly-stacked data. The doubly-stacked counterparts to the special names listed above are distinguished by replacing the 
second letter ('M' in the above examples) by the number '2' ({it:{cmd:S2stkid}}, {it:{cmd:S2nstks}}, etc.). Also, special 
names like "SMddMisCount" and "SMiiPlugCount" are used by {bf:stackMe} commands for variables that document the extent of 
missing data found, overall, when generating the primary outcome variable(s) for each command. 


{marker Regardingversion2}
{title:Note regarding version 2.0}

{pstd}
This release of {cmd:StackMe} is actually Version 2 of what was originally named {cmd:PTVtools} (the acronym stands 
for Propensity To Vote (Eijk et al 2006). It differs from {cmd:PTVtools} in having additional commands – 
{help genmeanstats:{ul:genme}anstats} and {help genplace:{ul:genpl}ace} (which also provides an interface to other 
{bf:Stata} commands and to user-written 
programs). {cmd:StackMe}’s user interface has been standardized across {cmd:StackMe} commands: pipe-delimited 
{varlist}s are available with all {cmd:StackMe} commands, not just with {cmd:genyhats}; all {cmd:StackMe} commands 
offer the same suite of options, invoked by the same option-names, to the extent that each option makes sense for the 
command concerned. The package also provides additional functionality by including {ifin} and {weight} expressions, 
along with double-stacking of datasets with nested contextual hierarchies.{break}
{space 3}The concept of a "utility program" has been introduced, named with initial characters "SM" instead of "gen",
along with facilities for linking to user-written programs that employ the same naming convention. Most importantly, 
many {cmd:StackMe} commands run considerably faster by an order of magnitude; and, as already mentioned, considerable 
effort has been put into early diagnosis of variable naming errors. This is especially true for {help genstacks}, 
{help geniimpute} and {help genyhats} (the commands most likely to involve all substantively relevant variables in 
a {cmd:StackMe} dataset). These elaborations to standard Stata syntax can be ignored if faster execution is not an issue. 
Command {help genstacks:{ul:genst}acks}, the command that was most in need of accelleration, now runs an order of magnitude 
faster even without use of these syntactical innovations.{break}
{space 3}Initially we are distributing a beta version of {cmd:StackMe} 2.0, which may still contain bugs and 
infelicities. Any comments and/or suggestions for improvements should be emailed to mark.franklin@trincoll.edu 
(if no response within a week, email the first author named below).{break}


{marker Authors}
{title:Authors}

{pstd}
Lorenzo De Sio - European University Institute (now at LUISS): ldesio@luiss.it{break}
Mark Franklin - European University Institute (now emeritus at Trinity College Connecticut): mark.franklin@trincoll.edu


{marker citation}
{title:Citations}

{pstd}
If you employ {bf:StackMe} in published work, please use the following citation:{break}
De Sio, L. and Franklin, M. (2011) "StackMe: A Stata package for manipulating multi-level data" 
(version 2.0), {it:Statistical Software Components}, Boston College Department of Economics.

{pstd}
To better understand generic variable analysis in a comparative framework see:{break}
Eijk, C. van der, Brug, W. van der, Kroh, M. and Franklin, M. (2006) "Rethinking the dependent variable in voting 
behavior: On the measurement and analysis of electoral utilities", {it:Electoral Studies} 25(3): 424-447.{p_end}
