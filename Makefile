ACCOUNT=klotio
IMAGE=pi-setup
VERSION?=0.1
VOLUMES=-v ${PWD}/boot_requirements.txt:/opt/klot-io/requirements.txt \
        -v ${PWD}/etc/:/opt/klot-io/etc/\
        -v ${PWD}/lib/:/opt/klot-io/lib/ \
        -v ${PWD}/www/:/opt/klot-io/www/ \
        -v ${PWD}/bin/:/opt/klot-io/bin/ \
        -v ${PWD}/config/:/opt/klot-io/config/ \
        -v ${PWD}/kubernetes/:/opt/klot-io/kubernetes/ \
        -v ${PWD}/service/:/opt/klot-io/service/ \
        -v ${PWD}/images/:/opt/klot-io/images/ \
		-v ${PWD}/secret/:/opt/klot-io/secret/
PORT=8083
KLOTIO_HOST?=klot-io.local


.PHONY: build shell boot api daemon gui export shrink config clean kubectl

cross:
	docker run --rm --privileged multiarch/qemu-user-static:register --reset

build:
	docker build . -f Dockerfile.setup -t $(ACCOUNT)/$(IMAGE)-setup:$(VERSION)

shell:
	docker run --privileged=true -it --network=host $(VARIABLES) $(VOLUMES) $(ACCOUNT)/$(IMAGE)-setup:$(VERSION) sh

boot:
	docker run --privileged=true -it --rm -v /Volumes/boot/:/opt/klot-io/boot/ $(VOLUMES) $(ACCOUNT)/$(IMAGE)-setup:$(VERSION) sh -c "bin/boot.py $(VERSION)"

api:
	scp lib/manage.py pi@$(KLOTIO_HOST):/opt/klot-io/lib/
	ssh pi@$(KLOTIO_HOST) "sudo systemctl restart klot-io-api"

daemon:
	scp lib/config.py pi@$(KLOTIO_HOST):/opt/klot-io/lib/
	ssh pi@$(KLOTIO_HOST) "sudo systemctl restart klot-io-daemon"

gui:
	scp -r www pi@$(KLOTIO_HOST):/opt/klot-io/
	ssh pi@$(KLOTIO_HOST) "sudo systemctl reload nginx"

export:
	bin/export.sh $(VERSION)

shrink:
	docker build . -f Dockerfile.shrink -t $(ACCOUNT)/$(IMAGE)-shrink:$(VERSION)
	docker run --privileged=true -it --rm $(VOLUMES) $(ACCOUNT)/$(IMAGE)-shrink:$(VERSION) sh -c "pishrink.sh images/pi-$(VERSION).img"

config:
	cp config/*.yaml /Volumes/boot/klot-io/config/
	docker-compose -f docker-compose.yml build
	docker-compose -f docker-compose.yml up

clean:
	docker-compose -f docker-compose.yml down

kubectl:
ifeq (,$(wildcard /usr/local/bin/kubectl))
	curl -LO https://storage.googleapis.com/kubernetes-release/release/$(KUBECTL_VERSION)/bin/darwin/amd64/kubectl
	chmod +x ./kubectl
	sudo mv ./kubectl /usr/local/bin/kubectl
endif
	mkdir -p secret
	rm -f secret/kubectl
	[ -f ~/.kube/config ] && cp ~/.kube/config secret/kubectl || [ ! -f ~/.kube/config ]
	docker run -it $(VARIABLES) $(VOLUMES) $(ACCOUNT)/$(IMAGE)-setup:$(VERSION) bin/kubectl.py
	mv secret/kubectl ~/.kube/config