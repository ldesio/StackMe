{smcl}
{cmd:help gendist}
{hline}

{title:Title}

{p2colset 5 16 16 2}{...}
{p2col :{cmd:gendist} {hline 2}}Generates distances from respondent self-placements for batter(ies) of spatial item(s){p_end}
{p2colreset}{...}


{title:Syntax}

{p 6 14 2}
{opt gendist} {varlist} [if][in][weight][{cmd:,} {it:options}]

{p 9 9 2}generates distances for a single battery of variables measured on the same scale as 
a single (optioned) respondent self-placement; alternatively,


{p 6 14 2}
{opt gendist} [if][in][weight][{help varname:selfplace}:] {help varlist} [{cmd:,} {it:options}] [ {bf:||} [{help varname:selfplace}:] 
				{help varlist} [{cmd:,} {it:options}] [ || ... ]

{p 9 9 2}generates distances for multiple  batteries (separated by "||"), each of which can be 
prifixed by a different respondent self-placement.
				

				
{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opth sel:fplace(varname)}}(required if not prefixing {varlist}) a variable containing the respondent's self-placement 
in the space (e.g. the issue space) in which {varlist} battery reference items (e.g. political parties) have been placed.{p_end}
{synopt :{opth nosel:fplace(varname)}}empty the prefix option (useful if wanting to 
use prefix variables instead of the prefix option).{p_end}
{synopt :{opth con:textvars(varlist)}}a set of variables identifying different electoral contexts
(by default all cases are treated as part of the same context).{p_end}
{synopt :{opt nocon:texts}}override the default behavior that generates distances within each context (if 
specified) separately.{p_end}
{synopt :{opth sta:ckid(varname)}}a variable identifying different "stacks", for which distances will be 
separately generated if {cmd:gendist} is issued after stacking.{p_end}
{synopt :{opt nosta:cks}}override the default behavior that treats each stack as a separate context.{p_end}
{synopt :{opt mis:sing(all|same|diff)}}basis for plugging missing values on battery placements.{p_end}
{synopt :{opt rou:nd}}rounds plugged values to the nearest integer.{p_end}
{synopt :{opt ppr:efix(name)}}prefix for generated (optionally mean-plugged) placement variables (default is "p_").{p_end}
{synopt :{opt mpr:efix(name)}}prefix for generated variables indicating original missing status of either 
component (item location or respondent location) of a distance measure (default is "m_").{p_end}
{synopt :{opt dpr:efix(name)}}prefix for generated distance variables (default is "d_").{p_end}
{synopt :{opt plu:gall}}replace ALL battery values by plugging-values generated in accordance with option {opt missing}, 
constant across respondents.{p_end}
{synopt :{opt mco:untname(name)}}name for a generated variable reporting original count of missing items; 
for each case (default is SMmco).{p_end}
{synopt :{opt mpc:ountname(name)}}name of a generated variable reporting the count
of missing items for each case after mean-plugging (default is SMmpc.{p_end}
{synopt :{opt rep:lace}}drops original party location variables, missing indicators and party placements 
after the generation of distances.{p_end}
{synopt :{opt lim:itdiag(#)}}limit progress reports to first # contexts for which distances are being calculated.{p_end}
{synopt :{opt nod:iag}}suppress progress reports.{p_end}

{p 5}Specific options all have default settings unless described as "required"


{synoptline}

{title:Description}

{pstd}
{cmd:gendist} generates Euclidean distances for batter(ies) of spatial variables (so-called "reference 
variables" listed in {varlist}) whose distances from each respondent's self-placement is to be measured, 
using the same spatial scale. Distances between the respondent and each reference variable are placed in 
corresponding members of a new battery of variables.

{pstd}
The variables in the new battery of distances are given names derived from appending the names in {varlist} to 
the prefix established in option {opt dprefix} (default {it:d_}).

{pstd}
If {opt missing} is optioned, {cmd:gendist} also generates a new battery of variables with the prefix established 
in option {bf:pprefix} (default {it:p_}) which is identical to the original battery but with missing values 
plugged by mean values. Those mean values can be mean placements (e.g. of political parties on the left-right 
scale) by all respondents, mean placements by respondents who place themselves at the same position as the 
reference placement, or mean placements by respondents who place themselves elsewhere, depending on what is 
specified in option {bf:missing}. 

{pstd}
Conventionally in published work the plugged value has been based on all placements. However, it might be 
thought that respondents having the same position would be more knowledgeable about the reference object 
concerned. Alternatively it might be thought that respondents having the same position might include 
individuals who were simply assuming that 'their' reference object (eg. political party) had the same 
position as themselves. Each of the {bf:missing} options is defensible theoretically so the user should 
think carefully about which to employ. The default is not to plug the missing data, so that distances 
are generated only for valid cases.

{pstd}
The {cmd:gendist} command can be issued before or after stacking. If issued after stacking, by default it 
treats each stack as a separate context to take into account along with any higher-level contexts. However, 
the {cmd:nostack} option can be employed to force {cmd:gendist} to ignore the stack-specific contexts. 
In addition, {cmd:gendist} can be employed with or without distinguishing between higher-level contexts, if 
any, (with or without the {cmd:contextvars} option) depending on what makes methodological sense.

{pstd} 
NOTE that it is unlikely to make methodological sense to employ {cmd:gendist} after stacking along with 
both the {cmd:nostack} and a {cmd:missing} option, since this would result in missing values being plugged 
with a mean that combined the values of what were (before stacking) several different variables.

{pstd}
NOTE ON MULTIPLE BATTERIES. In datasets derived from election studies (and perhaps more generally) 
it is quite common for some questions (eg about party locations on certain issues) to be asked 
only for a subset of the objects being investigated (eg. parties). Moreover, questions relating to those 
objects may not always list them in the same order. Yet stacked datasets (the type of datasets for which 
distances are normally wanted) absolutely require all batteries pertaining to the stacked objects 
to have the same suffixes for the same items, which only the user can check. See also the notes 
on multiple batteries in the help text for {help genstacks} and for {help gendummies}.

{pstd}
SPECIAL NOTE ON REFERENCE VALUES. The reference values from which distances to respondents are calculated 
(often the left-right or policy positions of political parties) might be assigned by experts or derive from 
some other external source. Alternatively, respondents might themselves be performing as "experts" in regard 
to the locations of the reference items in specific contexts. In that case it might be appropriate to use 
the {opt plu:gall} option to produce a constant value across all respondents in each context, based on the 
expertise of respondents deemed particularly expert. {opt mis:sing(mean)} plugging values are calculated 
across all (non-missing) responses (the same mean as produced by {help genmeans} or {help genplace}); 
but {opt mis:sing(same)} and {opt mis:sing(diff)} plugging values are each calculated across the subset of 
respondents defined by the option concerned. So {opt plu:gall}-processed reference values (held in generated 
{bf:p_}-prefixed variables by default) might in some circumstances be preferred to reference values generated 
by {help genmeans} or {help genplace}.


{title:Options}

{phang}
{opth selfplace(varname)} (required unless this {varname} already prefixes the preceding {varlist}) the variable 
containing the respondent's self-placement on the scale used for the corresponding battery of reference items.

{phang}
{opth contextvars(varlist)} if present, variables whose combinations identify different electoral contexts
(by default all cases are assumed to belong to the same context).

{phang}
{opt nocontexts} if present, overrides the default behavior of gendrating distances within each context (if 
specified) separately.

{phang}
{opth stackid(varname)} if specified, a variable identifying different "stacks", for which distances will be 
separately generated in the absence of the {cmd:nostack} option. The default is to use the "genstacks_stack" 
variable if the {cmd:gendist} command is issued after stacking.

{phang}
{opt nostacks} if present, overrides the default behavior of treating each stack as a separate context (has 
no effect if data are not stacked).

{phang}
{opth missing(all|same|diff)} if present, determines treatment of missing values for object placement variables
(by default they remain missing).{break}
  {space 3}If {bf:all} is specified, missing values are replaced with the overall mean placement of that object,
calculated on the whole sample for each context and/or stack.{break}
  {space 3}If {bf:same} is specified, missing values are replaced with the mean placement of the object, calculated 
only among those respondents that placed themselves on the same position as the object (seldom used).{break}
  {space 3}If {bf:diff} is specified, missing values are replaced with the mean placement of the object, calculated 
only among those respondents who placed themselves at a different position than the reference item (see 
discussion under {bf:Description}, above, regarding choice between these options).{break}
  {space 3}When missing values are plugged, a set of p_{it:varlist} variables is generated, and the original
variables are left unchanged (the p_ prefix can be altered by using the option {bf:pprefix}).{break}
More sophisticated imputation facilites are offered by {bf:{help geniimpute}}.{break}
NOTE: Consider using option {bf:plugall} to treat (e.g.) party locations as constant across respondents 
(see SPECIAL NOTE ON REFERENCE VALUES under {bf:Description}, above).

{phang}
{opt round} if present, causes rounding of all plugged values to the closest integer.

{phang}
{opt plugall} if present, causes ALL values of each reference variable to be replaced with plugging 
values calculated according to option {bf:missing}, thus yielding values that are constant across respondents. 
(see SPECIAL NOTE ON REFERENCE VALUES under {bf Description}, above).

{phang}
{opth dprefix(name)} if present, provides a prefix for generated distance variables (default is "d_").

{phang}
{opth pprefix(name)} if present, provides a prefix for generated mean-plugged placements (default is "p_").

{phang}
{opth mprefix(name)} if present, provides a prefix for generated variables indicating for each case whether, 
before mean-plugging of an item in the battery, either the item placement or the respondent placement was 
missing for that case (default is "m_").

{phang}
{opth mcountname(name)} if specified, name for a generated variable reporting original number of
missing items (default is to generate a variable named SMmc){p_end}

{phang}
{opth mpluggedcountname(name)} if specified, name for a generated variable reporting number of
missing items after mean-plugging, which could still be non-zero (even after all missing values 
on item positions have been plugged) if the respondent's own self-placement is missing (default is 
Generate a variable named SMmpc){p_end}

{phang}
{opt dropmissing} if specified, drops all party position and (optionally mean-plugged) placement 
variables after the generation of distance measures{p_end}

{phang}
{opt replace} if specified, drops original party placement variables after the generation of distance 
measures. Also all missing indicators and (optionally mean-plugged) placement variables{p_end}

{phang}
{opt limitdiag(#)} limit progress reports to first # contexts for which distances are being calculated{p_end}

{phang}
{opt nodiag} if specified, suppresses progress reports {p_end}

{p 4}Specific options all have default settings unless described as "required"



{title:Examples:}

{pstd}The following command generates distances on a left-right dimension, where party placements
are in variables lrp1-lrp10, and R's self-placement is in lrresp; missing placements are replaced
by simple mean-plugging, and then rounded to the nearest integer.{p_end}

{phang2}{cmd:. gendist lrp1-lrp10, selfplace(lrresp) missing(all) round}{p_end}

{*NEED ANOTHER, POST-STACKED WITHOUT THE CONTRASTING MISSING TREATMENTS}

{pstd}The following command generates distances on a tax dimension, where party-respondent
distances are computed under two different missing data treatments. Resulting y-hats are 
distinguished by having different prefixes according to missing treatment. Both sets of 
y-hats are rounded since that option was not changed for the second varlist.{p_end}

{phang2}{cmd:. gendist taxself: taxp1-taxp10, missing(all) dprefix(d1_) round || taxself: taxp1-taxp10,} 
{cmd:missing(diff) dpr(d2_)}{p_end}


{title:Generated variables}

{pstd}
{cmd:gendist} saves the following variables and variable sets (unless option {opt:replace} is used):

{synoptset 16 tabbed}{...}
{synopt:p_{it:var1} p_{it:var2} ... (or other prefix set by option {bf:pprefix})} a set of mean-plugged 
placement variables with names p_var1, p_var2, etc., where the names var1, var2, etc. match the original 
variable names. Those variables are left unchanged.{p_end}
{synopt:m_{it:var1} m_{it:var2} ... (or other prefix set by option {bf:mprefix})} a set of variables with    
names m_var1, m_var2, etc., where the names var1, var2, etc. match the original variable names of the 
battery of items. These variables indicate the original missingness of var1, var2, etc., or of the 
corresponding placement of the respondent on the scale concerned.{p_end}
{synopt:d_{it:var1} d_{it:var2 ...} (or other prefix set by option {bf:dprefix})} a set of distances 
from the respondent to each (mean-plugged if optioned) placement variable. These distance variables are 
named d_var1, d_var2, etc., where the names var1, var2, etc. match the original variable names. Those 
variables are left unchanged.{p_end}
{synopt:SMmc} a variable showing the original count of missing items for each case.{p_end}
{synopt:SM_mpc} a variable showing the count of remaining missing items for each case after 
mean-plugging.{p_end}

{phang}
The first two groups of prefixed variables (p_ and m_ in the example) are dropped along with the original 
variables if {it:replace} is optioned.

{phang}
A subsequent invocation of {cmd:gendist} will replace {it:SMmc} and {it:SMmpc} with 
new counts of missing values; so users should save these values after issuing the previous command, if they 
will be of later interest.

