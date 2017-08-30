DEPENDENCIES=$( cat `dirname $0`/requirements.txt )

for dep in $DEPENDENCIES; do
	echo
	echo
	echo $dep
	perl -M$dep -e '' && echo "$dep already installed" || cpan -f -i $dep || exit $?
	echo
done

