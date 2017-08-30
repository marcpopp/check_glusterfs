echo "FROM perl:latest"

# Install all out test dependencies
DEPENDENCIES=$( cat `dirname $0`/requirements.txt )

for dep in $DEPENDENCIES; do
	echo "RUN cpan -i $dep"
done
