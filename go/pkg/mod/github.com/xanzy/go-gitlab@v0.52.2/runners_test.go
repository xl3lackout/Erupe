//
// Copyright 2021, Sander van Harmelen
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

package gitlab

import (
	"encoding/json"
	"fmt"
	"net/http"
	"reflect"
	"testing"
	"time"
)

func TestDisableRunner(t *testing.T) {
	mux, server, client := setup(t)
	defer teardown(server)

	mux.HandleFunc("/api/v4/projects/1/runners/2", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, http.MethodDelete)
		w.WriteHeader(http.StatusNoContent)
	})

	_, err := client.Runners.DisableProjectRunner(1, 2, nil)
	if err != nil {
		t.Fatalf("Runners.DisableProjectRunner returns an error: %v", err)
	}
}

func TestListRunnersJobs(t *testing.T) {
	mux, server, client := setup(t)
	defer teardown(server)

	mux.HandleFunc("/api/v4/runners/1/jobs", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, http.MethodGet)
		fmt.Fprint(w, `[{"id":1},{"id":2}]`)
	})

	opt := &ListRunnerJobsOptions{}

	jobs, _, err := client.Runners.ListRunnerJobs(1, opt)
	if err != nil {
		t.Fatalf("Runners.ListRunnersJobs returns an error: %v", err)
	}

	want := []*Job{{ID: 1}, {ID: 2}}
	if !reflect.DeepEqual(want, jobs) {
		t.Errorf("Runners.ListRunnersJobs returned %+v, want %+v", jobs, want)
	}
}

func TestRemoveRunner(t *testing.T) {
	mux, server, client := setup(t)
	defer teardown(server)

	mux.HandleFunc("/api/v4/runners/1", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, http.MethodDelete)
		w.WriteHeader(http.StatusNoContent)
	})

	_, err := client.Runners.RemoveRunner(1, nil)
	if err != nil {
		t.Fatalf("Runners.RemoveARunner returns an error: %v", err)
	}
}

func TestUpdateRunnersDetails(t *testing.T) {
	mux, server, client := setup(t)
	defer teardown(server)

	mux.HandleFunc("/api/v4/runners/6", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, http.MethodPut)
		fmt.Fprint(w, exampleDetailResponse)
	})

	opt := &UpdateRunnerDetailsOptions{}

	details, _, err := client.Runners.UpdateRunnerDetails(6, opt, nil)
	if err != nil {
		t.Fatalf("Runners.UpdateRunnersDetails returns an error: %v", err)
	}

	want := expectedParsedDetails()
	if !reflect.DeepEqual(want, details) {
		t.Errorf("Runners.UpdateRunnersDetails returned %+v, want %+v", details, want)
	}
}

func TestGetRunnerDetails(t *testing.T) {
	mux, server, client := setup(t)
	defer teardown(server)

	mux.HandleFunc("/api/v4/runners/6", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, http.MethodGet)
		fmt.Fprint(w, exampleDetailResponse)
	})

	details, _, err := client.Runners.GetRunnerDetails(6, nil)
	if err != nil {
		t.Fatalf("Runners.GetRunnerDetails returns an error: %v", err)
	}

	want := expectedParsedDetails()
	if !reflect.DeepEqual(want, details) {
		t.Errorf("Runners.UpdateRunnersDetails returned %+v, want %+v", details, want)
	}
}

// helper function returning expected result for string: &exampleDetailRsp
func expectedParsedDetails() *RunnerDetails {
	proj := struct {
		ID                int    `json:"id"`
		Name              string `json:"name"`
		NameWithNamespace string `json:"name_with_namespace"`
		Path              string `json:"path"`
		PathWithNamespace string `json:"path_with_namespace"`
	}{ID: 1, Name: "GitLab Community Edition", NameWithNamespace: "GitLab.org / GitLab Community Edition", Path: "gitlab-ce", PathWithNamespace: "gitlab-org/gitlab-ce"}
	timestamp, _ := time.Parse("2006-01-02T15:04:05.000Z", "2016-01-25T16:39:48.066Z")
	return &RunnerDetails{
		Active:      true,
		Description: "test-1-20150125-test",
		ID:          6,
		IsShared:    false,
		RunnerType:  "project_type",
		ContactedAt: &timestamp,
		Online:      true,
		Status:      "online",
		Token:       "205086a8e3b9a2b818ffac9b89d102",
		TagList:     []string{"ruby", "mysql"},
		RunUntagged: true,
		AccessLevel: "ref_protected",
		Projects: []struct {
			ID                int    `json:"id"`
			Name              string `json:"name"`
			NameWithNamespace string `json:"name_with_namespace"`
			Path              string `json:"path"`
			PathWithNamespace string `json:"path_with_namespace"`
		}{proj},
		MaximumTimeout: 3600,
		Locked:         false,
	}
}

// helper function returning expected result for string: &exampleRegisterNewRunner
func expectedParsedNewRunner() *Runner {
	return &Runner{
		ID:    12345,
		Token: "6337ff461c94fd3fa32ba3b1ff4125",
	}
}

func TestRegisterNewRunner(t *testing.T) {
	mux, server, client := setup(t)
	defer teardown(server)

	mux.HandleFunc("/api/v4/runners", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, http.MethodPost)
		w.WriteHeader(http.StatusCreated)
		fmt.Fprint(w, exampleRegisterNewRunner)
	})

	opt := &RegisterNewRunnerOptions{}

	runner, resp, err := client.Runners.RegisterNewRunner(opt, nil)
	if err != nil {
		t.Fatalf("Runners.RegisterNewRunner returns an error: %v", err)
	}

	want := expectedParsedNewRunner()
	if !reflect.DeepEqual(want, runner) {
		t.Errorf("Runners.RegisterNewRunner returned %+v, want %+v", runner, want)
	}

	wantCode := 201
	if !reflect.DeepEqual(wantCode, resp.StatusCode) {
		t.Errorf("Runners.DeleteRegisteredRunner returned status code %+v, want %+v", resp.StatusCode, wantCode)
	}
}

// Similar to TestRegisterNewRunner but sends info struct and some extra other
// fields too.
func TestRegisterNewRunnerInfo(t *testing.T) {
	mux, server, client := setup(t)
	defer teardown(server)

	Token := "6337ff461c94fd3fa32ba3b1ff4125"
	Description := "some_description"
	Name := "some_name"
	Version := "13.7.0"
	Revision := "943fc252"
	Platform := "linux"
	Architecture := "amd64"
	Info := RegisterNewRunnerInfoOptions{
		&Name,
		&Version,
		&Revision,
		&Platform,
		&Architecture,
	}
	Active := true
	Locked := true
	RunUntagged := false
	TagList := []string{"tag1", "tag2"}
	MaximumTimeout := 45
	opt := RegisterNewRunnerOptions{
		&Token,
		&Description,
		&Info,
		&Active,
		&Locked,
		&RunUntagged,
		TagList,
		&MaximumTimeout,
	}

	want := &Runner{
		ID:          53,
		Description: Description,
		Active:      Active,
		IsShared:    false,
		IPAddress:   "1.2.3.4",
		Name:        Name,
		Online:      true,
		Status:      "online",
		Token:       "1111122222333333444444",
	}

	mux.HandleFunc("/api/v4/runners", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, http.MethodPost)
		w.WriteHeader(http.StatusCreated)
		j, err := json.Marshal(want)
		if err != nil {
			t.Fatalf("Failed to convert expected reply to JSON: %v", err)
		}
		fmt.Fprint(w, string(j))
	})

	runner, resp, err := client.Runners.RegisterNewRunner(&opt, nil)
	if err != nil {
		t.Fatalf("Runners.RegisterNewRunner returns an error: %v", err)
	}

	if !reflect.DeepEqual(want, runner) {
		t.Errorf("Runners.RegisterNewRunner returned %+v, want %+v", runner, want)
	}

	wantCode := 201
	if !reflect.DeepEqual(wantCode, resp.StatusCode) {
		t.Errorf("Runners.DeleteRegisteredRunner returned status code %+v, want %+v", resp.StatusCode, wantCode)
	}
}

func TestDeleteRegisteredRunner(t *testing.T) {
	mux, server, client := setup(t)
	defer teardown(server)

	mux.HandleFunc("/api/v4/runners", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, http.MethodDelete)
		w.WriteHeader(http.StatusNoContent)
	})

	opt := &DeleteRegisteredRunnerOptions{}

	resp, err := client.Runners.DeleteRegisteredRunner(opt, nil)
	if err != nil {
		t.Fatalf("Runners.DeleteRegisteredRunner returns an error: %v", err)
	}

	want := 204
	if !reflect.DeepEqual(want, resp.StatusCode) {
		t.Errorf("Runners.DeleteRegisteredRunner returned returned status code  %+v, want %+v", resp.StatusCode, want)
	}
}

func TestDeleteRegisteredRunnerByID(t *testing.T) {
	mux, server, client := setup(t)
	defer teardown(server)

	mux.HandleFunc("/api/v4/runners/11111", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, http.MethodDelete)
		w.WriteHeader(http.StatusNoContent)
	})

	rid := 11111

	resp, err := client.Runners.DeleteRegisteredRunnerByID(rid, nil)
	if err != nil {
		t.Fatalf("Runners.DeleteRegisteredRunnerByID returns an error: %v", err)
	}

	want := 204
	if !reflect.DeepEqual(want, resp.StatusCode) {
		t.Errorf("Runners.DeleteRegisteredRunnerByID returned returned status code  %+v, want %+v", resp.StatusCode, want)
	}
}

func TestVerifyRegisteredRunner(t *testing.T) {
	mux, server, client := setup(t)
	defer teardown(server)

	mux.HandleFunc("/api/v4/runners/verify", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, http.MethodPost)
		w.WriteHeader(http.StatusOK)
	})

	opt := &VerifyRegisteredRunnerOptions{}

	resp, err := client.Runners.VerifyRegisteredRunner(opt, nil)
	if err != nil {
		t.Fatalf("Runners.VerifyRegisteredRunner returns an error: %v", err)
	}

	want := 200
	if !reflect.DeepEqual(want, resp.StatusCode) {
		t.Errorf("Runners.VerifyRegisteredRunner returned returned status code  %+v, want %+v", resp.StatusCode, want)
	}
}
