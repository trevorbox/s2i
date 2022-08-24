package main

import (
	"bytes"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"encoding/json"

	"flag"

	"github.com/coreos/go-semver/semver"
)

type ListTags struct {
	Repository string   `json:"Repository,omitempty"`
	Tags       []string `json:"Tags,omitempty"`
}

func main() {
	var releaseFlag = flag.String("release", "0.1.0", "the Major.Minor.Patch release semver to create a new preRelease version from")
	var repositoryFlag = flag.String("repository", "", "the image repository, for example quay.io/trevorbox/pipeline-test-go")

	flag.Parse()

	release, err := semver.NewVersion(*releaseFlag)
	if err != nil {
		log.Println(err)
		os.Exit(1)
	}

	var newestRelevantSemver = semver.Version{
		Major:      release.Major,
		Minor:      release.Minor,
		Patch:      release.Patch,
		PreRelease: semver.PreRelease("0"),
	}

	cmd := exec.Command("skopeo", "list-tags", "docker://"+*repositoryFlag)
	cmdOutput := &bytes.Buffer{}
	cmdErr := &bytes.Buffer{}
	cmd.Stdout = cmdOutput
	cmd.Stderr = cmdErr
	err = cmd.Run()
	if err != nil {
		log.Println(cmdErr)
		os.Exit(1)
	}

	var arr ListTags
	_ = json.Unmarshal(cmdOutput.Bytes(), &arr)

	newestRelevantSemver.PreRelease = semver.PreRelease(strconv.FormatInt(determineNextPreRelease(arr.Tags, release), 10))
	fmt.Printf("%s\n", newestRelevantSemver.String())
	os.Exit(0)
}

func determineNextPreRelease(tags []string, release *semver.Version) int64 {
	var newestPreRelease int64 = -1
	for _, tag := range tags {

		semverTag, err := semver.NewVersion(strings.TrimPrefix(tag, "v"))

		if err != nil {
			// it is not a valid semver
			continue
		}

		if semverTag != nil {
			// tags = append(tags, semverTag)
			if semverTag.Major == release.Major && semverTag.Minor == release.Minor && semverTag.Patch == release.Patch {
				preRelease, err := strconv.ParseInt(string(semverTag.PreRelease), 10, 64)
				if err == nil {
					if preRelease > newestPreRelease {
						newestPreRelease = preRelease
					}
				}
			}
		}
	}

	newestPreRelease++
	return newestPreRelease
}
