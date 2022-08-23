package main

import (
	"bytes"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"

	"encoding/json"

	"github.com/coreos/go-semver/semver"
)

type ListTags struct {
	Repository string   `json:"Repository,omitempty"`
	Tags       []string `json:"Tags,omitempty"`
}

func main() {
	//"docker://quay.io/trevorbox/pipeline-test-go"
	cmd := exec.Command("skopeo", "list-tags", os.Args[1])
	cmdOutput := &bytes.Buffer{}
	cmdErr := &bytes.Buffer{}
	cmd.Stdout = cmdOutput
	cmd.Stderr = cmdErr
	err := cmd.Run()
	if err != nil {
		log.Println(cmdErr)
		os.Exit(1)
	}

	var arr ListTags
	_ = json.Unmarshal(cmdOutput.Bytes(), &arr)

	fmt.Printf("Unsorted Tags: %s\n", arr.Tags)
	var tags []*semver.Version
	for _, tag := range arr.Tags {

		t := strings.TrimPrefix(tag, "v")

		semverTag, err := semver.NewVersion(t)

		if err != nil {
			log.Println(err)
		}
		if semverTag != nil {
			tags = append(tags, semverTag)
		}
	}
	semver.Sort(tags)
	fmt.Printf("Sorted Tags: %s\n", tags)

	newest := tags[len(tags)-1]
	fmt.Printf("Most Recent: %s\n", newest.String())

	newest.BumpPatch()
	fmt.Printf("Next: v%s\n", newest.String())

}
