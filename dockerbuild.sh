export GA_DOCKER_IMAGE="repo-here:tag1"
echo tag=v1
echo value=v3
echo "::set-env name=GA_DOCKER_IMAGE::repo-here:tag2"
echo "::set-output name=GA_DOCKER_IMAGE4::repo-here:tag4"
