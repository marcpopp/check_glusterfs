DEPENDENCIES="
	Moose
	List::MoreUtils
	List::MoreUtils:XS
	MooseX::NonMoose
	XML::Generator
	TAP::Formatter::JUnit
	Clone
	TAP::Harness
	TAP::Formatter::Console
"

for dep in $DEPENDENCIES; do
	echo
	echo
	echo $dep
	perl -M$dep -e '' && echo "$dep already installed" || cpan -i $dep || exit $?
	echo
done

