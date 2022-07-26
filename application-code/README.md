This folder contains sample application code used to build container images. The container images are used as part of ECS service and task definitions in various examples. Some of the important elements found in each application code folder are:
* *Dockerfile* - contains instructions to build container images
* *templates* - this folder contains various files that are used by AWS CodeBuild during container build process. Some files to note are:
  * *buildspec.yml* file which is used by AWS CodeBuild service to build the container images.
  * *imagedefinition.json* file which is used in the *buildspec.yml* file to list the container names and images

You can try the examples with your own application. In your application repository, you will need atleast a *Dockerfile* and a *templates* folder with contents as described above.
