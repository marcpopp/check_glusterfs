echo "FROM perl:5.18.2"

# Install all out test dependencies
DEPENDENCIES=$( cat `dirname $0`/requirements.txt )

for dep in $DEPENDENCIES; do
	echo "RUN cpan -f -i $dep"
done
