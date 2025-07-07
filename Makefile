registry := registry.home.glroland.com
repo := paas
image := oai-hadoop-spark-notebook
tag := $(shell date +"%Y%m%d-%H%M%S")

namespace := test
workspace_name := oai-hadoop-spark-notebook

clean:
	rm -rf target

clean_ocp_resources:
	oc delete notebook $(workspace_name) -n $(namespace)
	oc delete pvc $(workspace_name)-storage -n $(namespace)

init:
	mkdir -p target

create_image:
	podman build . --platform linux/linux/amd64 -t $(registry)/$(repo)/$(image):$(tag)

push_image:
	podman push $(registry)/$(repo)/$(image):$(tag)

create_yaml: init
# Create notebook image stream
	sed -e 's/NB_NAME_FIELD/$(image)-$(tag)/g' templates/notebook_image_stream.yaml | \
	sed -e 's/NB_REGISTRY_FIELD/$(registry)/g' | \
	sed -e 's/NB_REPO_FIELD/$(repo)/g' | \
	sed -e 's/NB_IMAGE_FIELD/$(image)/g' | \
	sed -e 's/NB_TAG_FIELD/$(tag)/g' > target/notebook_image_stream.yaml

# Create PVC
	sed -e 's/WORKSPACE_NAME_FIELD/$(workspace_name)/g' templates/notebook_storage.yaml > target/notebook_storage.yaml

# Create notebook
	sed -e 's/NB_NAME_FIELD/$(image)-$(tag)/g' templates/notebook.yaml | \
	sed -e 's/WORKSPACE_NAME_FIELD/$(workspace_name)/g' | \
	sed -e 's/NAMESPACE_FIELD/$(namespace)/g' | \
	sed -e 's/NB_REGISTRY_FIELD/$(registry)/g' | \
	sed -e 's/NB_REPO_FIELD/$(repo)/g' | \
	sed -e 's/NB_IMAGE_FIELD/$(image)/g' | \
	sed -e 's/NB_TAG_FIELD/$(tag)/g' > target/notebook.yaml

deploy:
	oc apply -f target/notebook_storage.yaml
	oc apply -f target/notebook_image_stream.yaml
	oc apply -f target/notebook.yaml

build: create_image push_image create_yaml
