#!/bin/bash

################################################################################
# Ensure our environment variables are set
################################################################################
if [ "$PHP_VERSION" == "" ]; then
  echo "You must define a \$PHP_VERSION environment variable"
  exit 1
fi

if [ "$IMAGE_FLAVOUR" == "" ]; then
  echo "You must define a \$IMAGE_FLAVOUR environment variable"
  exit 1
fi

if [ "$DOCKER_IP" == "" ]; then
  DOCKER_IP="$(dinghy ip)"
fi

################################################################################
# Set our variables
################################################################################
IMAGE_NAME="test-$PHP_VERSION-$IMAGE_FLAVOUR"
TEST_DIR="$(pwd)/test"
TEST_OK_STRING="TEST OK"
TEST_PORT="8888"

################################################################################
# Kick off with some debug
################################################################################
echo ""
echo "Test Runner Configuration:"
echo ""
echo "PHP Version: $PHP_VERSION"
echo "Image Flavour: $IMAGE_FLAVOUR"

################################################################################
# Pull published image down so we can try and reuse layers
################################################################################
echo ""
echo "Pulling published images for layer cache.."
echo ""
docker pull meanbee/magento:${PHP_VERSION}-${IMAGE_FLAVOUR}

################################################################################
# Build our images
################################################################################
echo ""
echo "Building image.."
echo ""
cd $PHP_VERSION/$IMAGE_FLAVOUR && docker build -t $IMAGE_NAME . || exit 1
cd ../..

################################################################################
# Output the PHP version running in the image
################################################################################
echo ""
echo "Image PHP Version:"
echo ""
docker run $IMAGE_NAME php --version || exit 1

################################################################################
# Run CLI tests on all images
################################################################################
echo ""
echo "Running cli tests:"
echo ""

docker run --volume $TEST_DIR:/test $IMAGE_NAME php /test/test.php \
  | grep --context=1000 "$TEST_OK_STRING" || exit 1

################################################################################
# Run web server tests on apache image
################################################################################
if [ "$IMAGE_FLAVOUR" == "apache" ]; then
  echo ""
  echo "Running web server tests:"
  echo ""

  # Start the web server
  docker run -d --volume $TEST_DIR:/var/www/html -p $TEST_PORT:80 $IMAGE_NAME || exit 1
  echo ""

  # Spent up to a minute trying to connect to the web server
  max_attempts=12
  timeout=5
  attempt=0

  while (( $attempt < $max_attempts ))
  do
    curl $DOCKER_IP:$TEST_PORT/test.php \
      | grep --context=1000 "$TEST_OK_STRING"

    # Wait for a zero exit code before stopping
    if [[ $? == 0 ]]
    then
      break
    fi

    echo ""
    echo "Failed to connect to web server. Retrying in $timeout.."
    echo ""

    sleep $timeout
    attempt=$(( attempt + 1 ))
  done
fi