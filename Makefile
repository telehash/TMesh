all:
	mmark -xml2 -page tmesh.md > tmesh.xml
	xml2rfc tmesh.xml

install:
	go get github.com/miekg/mmark
	go install github.com/miekg/mmark/mmark
	sudo port install xml2rfc
