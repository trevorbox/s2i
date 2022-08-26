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

var Usage = func() {
	fmt.Fprintf(os.Stderr, "Usage of %s:\n", os.Args[0])
	flag.PrintDefaults()
	fmt.Fprintln(os.Stderr, "Description: A tool to calculate the next prerelease semver version (ie, MAJOR.MINOR.PATCH-PRERELEASE) based on the")
	fmt.Fprintln(os.Stderr, "             desired release MAJOR.MINOR.PATCH semver and existing prerelease tags in the remote container repository (queried by skopeo).")
}

func main() {

	var repositoryFlag = flag.String("repository", "", "(required) the image repository, for example quay.io/trevorbox/pipeline-test-go")
	var releaseFlag = flag.String("release", "0.1.0", "(optional) the MAJOR.MINOR.PATCH \"semver\" release version used to calculate the next prerelease version from remote tags in the repository")
	var authfileFlag = flag.String("authfile", "", "(optional) path of the authentication file for private registries used by skopeo")

	flag.Parse()

	release, err := semver.NewVersion(*releaseFlag)
	if err != nil {
		log.Printf("ERROR release semver parse error: %s", err)
		Usage()
		os.Exit(1)
	}

	if len(*repositoryFlag) == 0 {
		log.Print("ERROR repository not specified")
		Usage()
		os.Exit(1)
	}

	var newestRelevantSemver = semver.Version{
		Major:      release.Major,
		Minor:      release.Minor,
		Patch:      release.Patch,
		PreRelease: semver.PreRelease("0"),
	}

	var cmd *exec.Cmd
	if len(*authfileFlag) > 0 {
		cmd = exec.Command("skopeo", "list-tags", "docker://"+*repositoryFlag, "--authfile", *authfileFlag)
	} else {
		cmd = exec.Command("skopeo", "list-tags", "docker://"+*repositoryFlag)
	}

	cmdOutput := &bytes.Buffer{}
	cmdErr := &bytes.Buffer{}
	cmd.Stdout = cmdOutput
	cmd.Stderr = cmdErr
	err = cmd.Run()
	if err != nil {
		log.Printf("ERROR skopeo: %s", err)
		Usage()
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
