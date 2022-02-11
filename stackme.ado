capture program drop stackme
program define stackme

	local subcommands gendist gendummies genmeans genplace genstacks genyhats iimpute
	local commandpos : list posof "`1'" in subcommands
	
	if (`commandpos'==0) {
		// not a StackMe sub command
		display as error "'`1'' is not a StackMe subcommand"
		exit 199
	}
	else {
		// runs everything after "stackme"
		`0'
	}
end program
