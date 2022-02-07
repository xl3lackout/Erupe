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
	"fmt"
	"net/http"
	"reflect"
	"testing"
)

func TestGetGlobalSettings(t *testing.T) {
	mux, server, client := setup(t)
	defer teardown(server)

	mux.HandleFunc("/api/v4/notification_settings", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, http.MethodGet)
		fmt.Fprintf(w, `{
			"level": "participating",
			"notification_email": "admin@example.com"
		  }`)
	})

	settings, _, err := client.NotificationSettings.GetGlobalSettings()
	if err != nil {
		t.Errorf("NotifcationSettings.GetGlobalSettings returned error: %v", err)
	}

	want := &NotificationSettings{
		Level:             1,
		NotificationEmail: "admin@example.com",
	}
	if !reflect.DeepEqual(settings, want) {
		t.Errorf("NotificationSettings.GetGlobalSettings returned %+v, want %+v", settings, want)
	}
}
