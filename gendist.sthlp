{smcl}
{cmd:help gendist}
{hline}

{title:Title}

{p2colset 5 16 16 2}{...}
{p2col :{cmdab:gendi:st} {hline 2}}Generates distances from respondent self-placements for batter(ies) of spatial item(s){p_end}
{p2colreset}{...}


{title:Syntax}

{p 6 14 2}
{cmdab:gendi:st} {varlist} [if][in][weight]{cmd:,} {it:options}

{p 9 9 2}generates distances for a single battery of variables measured on the same scale as a single (optioned) 
input variable holding self-placements for each respondent

{p 9}or

{p 6 14 2}
{cmdab:gendi:st} [{help varname:selfplace}:] {varlist} [if][in][weight] [ {bf:||} [{help varname:selfplace}:] 
				{help varlist} [weight] [ || ... ] || {varlist} [weight]{cmd:,} {it:options}

{p 9 9 2}generates distances for multiple  batteries (separated by "||"), each of which can be 
prefixed by a matching respondent self-placement and each of them applying the same options.

	
{p 4 4 2}Though illustrated with especially appropriate examples, the two syntax formats are interchangeable. 
Each can be used with either stacked or unstacked data. {bf:Speed of execution} can be much increased by grouping 
together varlists that employ the same options (especially useful if the variables in each battery are being 
individually enumerated using Syntax 2). In that case 'if/in' expressions should suffix the first varlist and 
', options...' should suffix the final {varlist}. Weights can be specified after any or all {varlist}s.

{p 6 8 2}{bf:If the data are not yet stacked:} each varlist should enumerate the battery members for which distances 
will be calculated, as illustrated by the second syntax.{p_end}
{p 6 8 2}{bf:If the data are already stacked:} each variable should name the battery whose observations had been 
battery members before stacking (and whose unstacked stubnames now name the stacked batteries). Distances are 
calculated separately for each stack and context (unless otherwise optioned).{p_end}

{p 4 4 2}Names of resulting distance measures for each member of each {varlist} are constructed by prefixing (by 
"dd_" or such other prefix as might be set by option {opt dpr:efix}) the name of the variable for which distances 
to the {it:selfplacement} measure are calculated.

{p 4 4 2}aweights, fweights, iweights, and pweights are allowed; see {help weight}.

				
{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt sel:fplace(varname)}}(required if not prefixing {varlist}) a variable containing the respondent's 
self-placement in the space (e.g. the issue space) in which {varlist} battery reference items (e.g. political 
parties) have been placed.{p_end}
{synopt :{opt con:textvars(varlist)}}(generally unspecified) a set of variables identifying the different electoral contexts within 
which distances will be separately generated (required if the default contextvars, recorded as a 'data characteristic' 
by command {cmdab:SMcon:textvars}, is to be overriden){p_end}
{synopt :{opt nocon:texts}}override the default behavior that generates distances within each context (if 
specified) separately.{p_end}
{synopt :{opt nosta:cks}}override the default behavior that treats each stack as a separate context (has 
no effect if data are not stacked).{p_end}
{synopt :{opt mis:sing(all|diff|dif2}}basis for plugging missing values on battery placements (see 
{help gendist##missing:missing} for details).{p_end}
{synopt :{opt plugall}}replace all values of each reference variable with plugging values calculated according to option 
{opt mis:sing}, thus yielding values that are constant across respondents. See the SPECIAL NOTE ON 
{help gendist##referencevalues:REFERENCE VALUES}.{p_end}
{synopt :{opt pro:ximities}}generate proximity measures instead of distances (includes a check on missing data handling).{p_end}
{synopt :{opt rou:nd}}rounds calculated distances/proximities to the nearest integer (to nearest 0.1 if data are proportions).{p_end}
{synopt :{opt mpr:efix(name)}}replacement for 2nd char of prefix identifying generated variables indicating original missing 
status of an item placement measure (default is "dm_").{p_end}
{synopt :{opt ppr:efix(name)}}replacement for 2nd char of prefix identifying generated (optionally mean-plugged) placement variables 
(default is "dp_").{p_end}
{synopt :{opt dpr:efix(name)}}replacement for 2nd char of prefix identifying generated distance measures (default is "dd_").{p_end}
{synopt :{opt xpr:efix(name)}}replacement for 2nd char or prefix identifying generated proximity measures (default is "dx_").{p_end}
{synopt :{opt apr:efix(name)}}one or more text characters to replace the "_" character following the (dm, dp, dd or dx) 
initial characters in ALL of the default prefixes mentioned above (should end with a "_" character).{p_end}
{synopt :{opt mcountname(name)}}if specified, name for a generated variable reporting original number of missing 
items (default is to generate a variable named SMdmisCount).{p_end}
{synopt :{opt mpluggedcountname(name)}}if specified, name for a generated variable reportingg the number of missing 
items after mean-plugging (default is to generate a variable named SMdmplugcound.{p_end}
{synopt :{opt kee:pmissing}}keep missing indicators even if {opt rep:lace} is optioned (see below).{p_end}
{synopt :{opt rep:lace}}drop original party location variables, party placements and missing indicators (unless {opt keep:missing} 
– see above – was also optioned).{p_end}
{synopt :{opt lim:itdiag(#)}}limit progress reports to first # contexts for which distances are being calculated.{p_end}
{synopt :{opt nod:iag}}suppress progress reports; equivalent to 'limitdiag(0)'.{p_end}

{p 5}Specific options all have default settings unless described as "required"


{synoptline}

{title:Description}

{pstd}
{cmd:gendist} generates Euclidean distances (optionally proximities) for batter(ies) of spatial variables 
(so-called "reference variables" listed in {varlist}) whose distances from each respondent's self-placement 
is to be measured, using the same spatial scale. Distances between the respondent and each reference variable 
are placed in corresponding members of a new battery of variables.

{pstd}
The variables in the new battery of distances are given names derived from appending the names in {varlist} to 
the prefix established in option {opt dprefix} (default {it:dd_}).

{marker missing}{...}
{p 4 4}If {opt mis:sing} is optioned, {cmd:gendist} also generates a new battery of variables with the prefix established  
in option {bf:pprefix} (default {it:dp_}); a battery that holds the values that will be used to plug missing 
placement values. Plugging values are mean values of non-missing placements (e.g. of political parties on a 
left-right scale), made by respondents who are effectively treated as "experts" in regard to these 
placements. Placements can be refined by using the expertise only of certain respondents: those who placed 
themselves elsewhere than where they placed the item being placed. This refinement supposes that the judgements 
of certain respondent may be biased by psychological influences known as {it:projection} and {it:assimilation} 
effects. Such effects are only evident among respondents placing the item where they place themselves. Many such 
respondents will of course be "false positives" – respondents who would have reported the same positions even without 
projection or assimilation influences. But the remaining respondents should be better judges of item locations 
than the full pool of all respondents (the same assumption is made when rejecting prospective jurors from a 
criminal trial). Taking the same supposition a step further, users can instead option that gendist plug even the 
non-missing placements of such respondents; but care should be taken regarding such a second step. If the user 
is interested only in item locations, the second step would be reasonable; but users interested in respondent 
behavior should bear in mind that such a second step will greatly dampen response variability, with likely 
knock-on effects for research findings. To address this problem, a fourth missing option is provided that randomly 
perturbs the plugging value for all respondents receiving those values, so that the variance of the plugged 
variable matches the variance of the original (as is done by default for imputed values generated by 
{help geniimpute:{ul:genii}mpute}).{break}
{space 3}The default is not to plug the missing data, so that distances (or proximities) are generated only 
for valid observations.{p_end}

{pstd}
The {cmd:gendist} command can be issued before or after stacking. If issued after stacking, by default it 
treats each stack as a separate context to take into account along with any higher-level contexts. However, 
the {opt nosta:ck} option can be employed to force {cmd:gendist} to ignore the stack-specific contexts. 
In addition, {cmdab:gendi:st} can be employed with or without distinguishing between higher-level contexts, if 
any, (with or without the {opt con:textvars} option) depending on what makes methodological sense.

{pstd} 
NOTE that it is unlikely to make methodological sense to employ {cmd:gendist} after stacking along with 
both the {opt nosta:ck} and a {cmd:missing} option, since this would result in missing values being plugged 
with a mean that combined the values of what were (before stacking) several different variables.

{pstd}
NOTE ON MULTIPLE BATTERIES. In datasets derived from election studies (and perhaps more generally) 
it is quite common for some questions (eg. about party locations on certain issues) to be asked 
only for a subset of the objects being investigated (eg. parties). Moreover, questions relating to those 
objects may not always list them in the same order. Yet stacked datasets (the type of datasets for which 
distances are normally wanted) absolutely require all batteries pertaining to the stacked objects 
to have the same suffixes for the same items, which only the user can check. See also the notes 
on multiple batteries in the help text for {help genstacks} and for {help gendummies}.

{marker referencevalues}{...}
{p 4 4}SPECIAL NOTE ON REFERENCE VALUES. With survey data, reference values from which distances to respondent 
self-placements are calculated (often the left-right or policy positions of political parties) might be 
assigned by experts or derive from some other external source. Alternatively, respondents might themselves 
be performing as "experts" in regard to the locations of the reference items in specific contexts. In that 
case it might be appropriate to use the {opt plu:gall} option to produce a constant value across all 
respondents in each context, based on the expertise of respondents deemed particularly expert. {opt mis:sing(mean)} 
plugging values are calculated across all (non-missing) responses (the same mean as produced by {help genmeanstats} 
or {help genplace}); but {opt mis:sing(diff)} plugging values are each calculated across the subset of respondents 
that, for each reference item, placed that item elsewhere than they placed themselves. So {opt plu:gall}-processed 
reference values (held in generated {bf:dp_}-prefixed variables by default) might in some circumstances be 
preferred to mean values generated by {help gensmeanstats} or {help genplace}.


{title:Options}

{phang}
{opth sel:fplace(varname)} (required unless this {varname} already prefixes the relevant {varlist}) the variable 
containing the respondent's self-placement on the scale used for the corresponding battery of reference items.

{phang}
{opt con:textvars(varlist)} (generally unspecified) a set of variables identifying the different contexts within 
which distances will be separately generated. By default, context varnames are taken from a Stata .dta file 
{help char:characteristic} established by {cmd:stackMe}'s command {cmdab:SMcon:textvars} the first time this 
file was opened for {help use} by a {cmd:stackMe} command; so this option is required if the default is 
to be overriden.{p_end}

{phang}
{opt nocon:texts} if present, overrides the default behavior of gendrating distances within each context (if 
specified) separately.

{phang}
{opt nosta:cks} if present, overrides the default behavior of treating each stack as a separate context (has 
no effect if data are not stacked).

{phang}
{opth mis:sing(all|diff|dif2} if present, determines treatment of missing values for object placement variables
(by default they remain missing).{break}
  {space 3}If {bf:all} is specified, missing values are replaced by the overall mean placement of each object,
each of them calculated over the whole set of observations for each context and/or stack.{break}
  {space 3}If {bf:diff} is specified, missing values are replaced with the mean placement of each object, calculated 
over just those respondents who placed themselves at a different position than they placed the object (see 
discussion under {bf:Description}, above, regarding this choice).{break}
  {space 3}If {bf:dif2} is specified, then not only missing values are plugged but also the positions of respondents 
ignored in the calculation of any specific plugging value – those respondents who placed themselves where they 
placed the object concerned. But this option requires option {opt plu:gall} (below) because it truncates the variance in 
respondent positions for those respondents treated as though actual responses were missing and so only makes sense when 
generating a mean that is constant across respondents.{break}
   {bf:NOTE} that these missing treatments only makes sense where placements are obtained from the same respondents 
whose self-placements are used in the calculation of distances. See also the SPECIAL NOTE ON 
{help gendist##referencevalues:REFERENCE VALUES} under {bf:Description}, above).

{phang}
{opt plu:gall} if present, causes ALL values of each reference variable to be replaced with plugging 
values calculated according to option {opt mis:sing}, thus yielding values that are constant across 
respondents. See the SPECIAL NOTE ON REFERENCE VALUES under {bf:Description}, above).

{phang}
{opth pro:ximities(name)} if specified, generate proximity measures instead of distances (includes a rudimentary 
but essential diagnostic check for correct missing data handling).{p_end}

{phang}
{opt rou:nd} if present, produces rounding of all calculated distances to the closest integer (nearest single-digit 
decimal if the maximum value of the item position is no greater than 1).{p_end}

{phang}
{opth mpr:efix(name)} if present, provides one or more text characters that replace(s) the second (and any subsequent) 
character(s) preceeding the end-of-prefix symbol ("_") of a prefix identifying a generated missing value indicator 
variable (default is "dm_").{p_end}

{phang}
{opth ppr:efix(name)} if present, provides one or more text characters that replace(s) the second (and any subsequent) 
character(s) preceeding the end-of-prefix symbol ("_") of a prefix identifying a generated variable that holds plugging 
values to replace missing values of an item placement (default is "dp_").{p_end}

{phang}
{opth dpr:efix(name)} if present, provides one or more text characters that replace(s) the second (and any subsequent) 
character(s) preceeding the end-of-prefix symbol ("_") of a prefix identifying a generated distance measure (default is 
"dd_").{p_end}

{phang}
{opth xpr:efix(name)} if present, provides one or more text characters that replace(s) the second character (and any 
subsequent) character(s) preceeding the end-of-prefix symbol ("_") of a prefix identifying a generated proximity measure 
(default is "dx_").{p_end}

{phang}
{opth apr:efix(text)} if present, provides one or more text characters that replace(s) the end-of-prefix symbol ("_") 
following the (dm, dp, dd or dx) initial characters (or their replacements) in ALL of the default prefixes mentioned 
above (should end with a "_" character). Provides a simple means of ALTERING these prefixes in an identical fashion 
across ALL (hence the choice of prefix initial) four prefixes mentioned above, perhaps to distinguish different 
treatments in terms of mean-plugging, weighting, subsetting, or the like.{p_end}

{phang}
{opth mco:untname(name)} if specified, name for a generated variable reporting original number of missing items (default 
is to generate a variable named SMdmisCount).{p_end}

{phang}
{opth mpl:uggedcountname(name)} if specified, name for a generated variable reporting the number of missing items after 
mean-plugging, which could still be non-zero (even after all possible missing values on item positions have been plugged) 
if, as is common, there are respondents whose own self-placement is missing (default is to generate a variable named 
SMdplugMisCount). NOTE that missing respondent self-placements can by plugged by using {cmd:stackMe}'s {help {ul:genii}mpute} 
command.{p_end}

{phang}
{opt kee:pmissing} if specified, keeps mean-plugged placement variables even if {opt rep:lace} (see below) is optioned.{p_end}

{phang}
{opt rep:lace} if specified, drops original party placement variables after the generation of distance measures. Also drops 
mean-plugged placement variables and missing indicators (unless {opt kee:pmissing} – see above – is also optioned).{p_end}

{phang}
{opt lim:itdiag(#)} limit progress reports to first # contexts for which distances are being calculated 
(or first # warnings, if issued).{p_end}

{phang}
{opt nodia:g} if specified, suppresses progress reports {p_end}

{p 4}Specific options all have default settings unless described as "required"



{title:Examples:}

{pstd}The following command generates distances on a left-right dimension, where party placements
are in variables lrp1-lrp10 (variables that have not been stacked), and R's self-placement is in 
lrresp; missing placements are replaced by simple mean-plugging and then rounded to the nearest integer.{p_end}

{phang2}{cmd:. gendist lrp1-lrp10, selfplace(lrresp) missing(all) round}{p_end}

{pstd}The following command generates distances on two different policy dimensions, taxes and foreign 
aid, for measures that have been stacked. Resulting distance measures will be distinguished by different 
stub names, depending on the stub names used in each {varlist}. Both sets of distances are are rounded 
and based on mean party placements of respondents who placed the parties differently than they placed 
themselves.{p_end}

{phang2}{cmd:. gendist taxself: taxp, missing(dif) round || aidself: aidp}{p_end}


{title:Generated variables}

{pstd}
{cmd:gendist} saves the following variables and variable sets (unless option {opt:replace} is used):

{synoptset 16 tabbed}{...}
{synopt:dp_{it:var1} dp_{it:var2} ... (or other prefix set by options {bf:pprefix} or {bf:aprefix})} a set of 
mean-plugged placement variables with names dp_var1, dp_var2, etc., where the names var1, var2, etc. match the 
original variable names of battery placement items. Those original variables are left unchanged, unless 
'replace' was optioned.{p_end
{synopt:dm_{it:var1} dm_{it:var2} ... (or other prefix set by options {bf:mprefix} or {bf:aprefix})} a set of 
variables with names dm_var1, dm_var2, etc., where the names var1, var2, etc. match the original variable 
names of battery placement items. The new variables indicate the original missingness of var1, var2, 
etc., before missing values were plugged. The original variables are left unchanged, unless 'replace' was 
optioned.{p_end}
{synopt:dd_{it:var1} dd_{it:var2 ...} (or other prefix set by options {bf:dprefix} or {bf:aprefix})} 
a set of distances from an optioned self-placement variable to each (mean-plugged if optioned) item placement 
variable. The new distance measures are named dd_var1, dd_var2, etc., where the names var1, var2, etc. match 
the original variable names of battery placement items. Those measures are left unchanged unless 'replace' is 
optioned.{p_end}
{synopt:dx_{it:var1} dx_{it:var2 ...} (or other prefix set by options {bf:dprefix} or {bf:aprefix})} 
a set of proximities between an optioned self-placement variable and each (mean-plugged if optioned) item 
placement variable. The new proximity measures are named dx_var1, dx_var2, etc., where the names var1, var2, 
etc. match the original variable names of battery placement items. Those measures are left unchanged unless 
'replace' is optioned.{p_end}
{synopt:SMdmisCount} a variable showing the original count of missing items for each observation.{p_end}
{synopt:SMdplugMisCount} a variable showing the count of remaining missing items for each observation after 
mean-plugging.{p_end}

{phang}
The final two groups of prefixed variables (dd_ and dx_ in the example) are alternative outcome variables. 
Which group is generated in practice depends on whether option {opt pro:ximities} is specified. The first  
two groups of prefixed variables (dp_ and dm_ in the example) are dropped along with the original variables 
if {it:replace} is optioned (unless {opt kee:pmissing} is also optioned, overriding the {opt rep:lace} 
option for "dm_"-prefixed variables).{p_end} 
.

{phang}
A subsequent invocation of {cmd:gendist} will replace {it:SMmisCount} and {it:SMplugMisCount} with 
new counts of missing values; so users should save these values under more specific names, after issuing 
the previous command, if they will be of later interest.

