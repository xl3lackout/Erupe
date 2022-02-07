// Copyright 2021 Google LLC.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Code generated file. DO NOT EDIT.

// Package baremetalsolution provides access to the Bare Metal Solution API.
//
// For product documentation, see: https://cloud.google.com/bare-metal
//
// Creating a client
//
// Usage example:
//
//   import "google.golang.org/api/baremetalsolution/v1alpha1"
//   ...
//   ctx := context.Background()
//   baremetalsolutionService, err := baremetalsolution.NewService(ctx)
//
// In this example, Google Application Default Credentials are used for authentication.
//
// For information on how to create and obtain Application Default Credentials, see https://developers.google.com/identity/protocols/application-default-credentials.
//
// Other authentication options
//
// To use an API key for authentication (note: some APIs do not support API keys), use option.WithAPIKey:
//
//   baremetalsolutionService, err := baremetalsolution.NewService(ctx, option.WithAPIKey("AIza..."))
//
// To use an OAuth token (e.g., a user token obtained via a three-legged OAuth flow), use option.WithTokenSource:
//
//   config := &oauth2.Config{...}
//   // ...
//   token, err := config.Exchange(ctx, ...)
//   baremetalsolutionService, err := baremetalsolution.NewService(ctx, option.WithTokenSource(config.TokenSource(ctx, token)))
//
// See https://godoc.org/google.golang.org/api/option/ for details on options.
package baremetalsolution // import "google.golang.org/api/baremetalsolution/v1alpha1"

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	googleapi "google.golang.org/api/googleapi"
	gensupport "google.golang.org/api/internal/gensupport"
	option "google.golang.org/api/option"
	internaloption "google.golang.org/api/option/internaloption"
	htransport "google.golang.org/api/transport/http"
)

// Always reference these packages, just in case the auto-generated code
// below doesn't.
var _ = bytes.NewBuffer
var _ = strconv.Itoa
var _ = fmt.Sprintf
var _ = json.NewDecoder
var _ = io.Copy
var _ = url.Parse
var _ = gensupport.MarshalJSON
var _ = googleapi.Version
var _ = errors.New
var _ = strings.Replace
var _ = context.Canceled
var _ = internaloption.WithDefaultEndpoint

const apiId = "baremetalsolution:v1alpha1"
const apiName = "baremetalsolution"
const apiVersion = "v1alpha1"
const basePath = "https://baremetalsolution.googleapis.com/"
const mtlsBasePath = "https://baremetalsolution.mtls.googleapis.com/"

// OAuth2 scopes used by this API.
const (
	// See, edit, configure, and delete your Google Cloud data and see the
	// email address for your Google Account.
	CloudPlatformScope = "https://www.googleapis.com/auth/cloud-platform"
)

// NewService creates a new Service.
func NewService(ctx context.Context, opts ...option.ClientOption) (*Service, error) {
	scopesOption := option.WithScopes(
		"https://www.googleapis.com/auth/cloud-platform",
	)
	// NOTE: prepend, so we don't override user-specified scopes.
	opts = append([]option.ClientOption{scopesOption}, opts...)
	opts = append(opts, internaloption.WithDefaultEndpoint(basePath))
	opts = append(opts, internaloption.WithDefaultMTLSEndpoint(mtlsBasePath))
	client, endpoint, err := htransport.NewClient(ctx, opts...)
	if err != nil {
		return nil, err
	}
	s, err := New(client)
	if err != nil {
		return nil, err
	}
	if endpoint != "" {
		s.BasePath = endpoint
	}
	return s, nil
}

// New creates a new Service. It uses the provided http.Client for requests.
//
// Deprecated: please use NewService instead.
// To provide a custom HTTP client, use option.WithHTTPClient.
// If you are using google.golang.org/api/googleapis/transport.APIKey, use option.WithAPIKey with NewService instead.
func New(client *http.Client) (*Service, error) {
	if client == nil {
		return nil, errors.New("client is nil")
	}
	s := &Service{client: client, BasePath: basePath}
	s.Projects = NewProjectsService(s)
	return s, nil
}

type Service struct {
	client    *http.Client
	BasePath  string // API endpoint base URL
	UserAgent string // optional additional User-Agent fragment

	Projects *ProjectsService
}

func (s *Service) userAgent() string {
	if s.UserAgent == "" {
		return googleapi.UserAgent
	}
	return googleapi.UserAgent + " " + s.UserAgent
}

func NewProjectsService(s *Service) *ProjectsService {
	rs := &ProjectsService{s: s}
	rs.Locations = NewProjectsLocationsService(s)
	rs.ProvisioningQuotas = NewProjectsProvisioningQuotasService(s)
	return rs
}

type ProjectsService struct {
	s *Service

	Locations *ProjectsLocationsService

	ProvisioningQuotas *ProjectsProvisioningQuotasService
}

func NewProjectsLocationsService(s *Service) *ProjectsLocationsService {
	rs := &ProjectsLocationsService{s: s}
	return rs
}

type ProjectsLocationsService struct {
	s *Service
}

func NewProjectsProvisioningQuotasService(s *Service) *ProjectsProvisioningQuotasService {
	rs := &ProjectsProvisioningQuotasService{s: s}
	return rs
}

type ProjectsProvisioningQuotasService struct {
	s *Service
}

// InstanceConfig: Configuration parameters for a new instance.
type InstanceConfig struct {
	// ClientNetwork: Client network address.
	ClientNetwork *NetworkAddress `json:"clientNetwork,omitempty"`

	// Hyperthreading: Whether the instance should be provisioned with
	// Hyperthreading enabled.
	Hyperthreading bool `json:"hyperthreading,omitempty"`

	// Id: A transient unique identifier to idenfity an instance within an
	// ProvisioningConfig request.
	Id string `json:"id,omitempty"`

	// InstanceType: Instance type.
	InstanceType string `json:"instanceType,omitempty"`

	// Location: Location where to deploy the instance.
	Location string `json:"location,omitempty"`

	// OsImage: OS image to initialize the instance.
	OsImage string `json:"osImage,omitempty"`

	// PrivateNetwork: Private network address, if any.
	PrivateNetwork *NetworkAddress `json:"privateNetwork,omitempty"`

	// UserNote: User note field, it can be used by customers to add
	// additional information for the BMS Ops team (b/194021617).
	UserNote string `json:"userNote,omitempty"`

	// ForceSendFields is a list of field names (e.g. "ClientNetwork") to
	// unconditionally include in API requests. By default, fields with
	// empty or default values are omitted from API requests. However, any
	// non-pointer, non-interface field appearing in ForceSendFields will be
	// sent to the server regardless of whether the field is empty or not.
	// This may be used to include empty fields in Patch requests.
	ForceSendFields []string `json:"-"`

	// NullFields is a list of field names (e.g. "ClientNetwork") to include
	// in API requests with the JSON null value. By default, fields with
	// empty values are omitted from API requests. However, any field with
	// an empty value appearing in NullFields will be sent to the server as
	// null. It is an error if a field in this list has a non-empty value.
	// This may be used to include null fields in Patch requests.
	NullFields []string `json:"-"`
}

func (s *InstanceConfig) MarshalJSON() ([]byte, error) {
	type NoMethod InstanceConfig
	raw := NoMethod(*s)
	return gensupport.MarshalJSON(raw, s.ForceSendFields, s.NullFields)
}

// InstanceQuota: A resource budget.
type InstanceQuota struct {
	// AvailableMachineCount: Number of machines than can be created for the
	// given location and instance_type.
	AvailableMachineCount int64 `json:"availableMachineCount,omitempty"`

	// InstanceType: Instance type.
	InstanceType string `json:"instanceType,omitempty"`

	// Location: Location where the quota applies.
	Location string `json:"location,omitempty"`

	// ForceSendFields is a list of field names (e.g.
	// "AvailableMachineCount") to unconditionally include in API requests.
	// By default, fields with empty or default values are omitted from API
	// requests. However, any non-pointer, non-interface field appearing in
	// ForceSendFields will be sent to the server regardless of whether the
	// field is empty or not. This may be used to include empty fields in
	// Patch requests.
	ForceSendFields []string `json:"-"`

	// NullFields is a list of field names (e.g. "AvailableMachineCount") to
	// include in API requests with the JSON null value. By default, fields
	// with empty values are omitted from API requests. However, any field
	// with an empty value appearing in NullFields will be sent to the
	// server as null. It is an error if a field in this list has a
	// non-empty value. This may be used to include null fields in Patch
	// requests.
	NullFields []string `json:"-"`
}

func (s *InstanceQuota) MarshalJSON() ([]byte, error) {
	type NoMethod InstanceQuota
	raw := NoMethod(*s)
	return gensupport.MarshalJSON(raw, s.ForceSendFields, s.NullFields)
}

// ListProvisioningQuotasResponse: Response for ListProvisioningQuotas.
type ListProvisioningQuotasResponse struct {
	// NextPageToken: Token to retrieve the next page of results, or empty
	// if there are no more results in the list.
	NextPageToken string `json:"nextPageToken,omitempty"`

	// ProvisioningQuotas: The provisioning quotas registered in this
	// project.
	ProvisioningQuotas []*ProvisioningQuota `json:"provisioningQuotas,omitempty"`

	// ServerResponse contains the HTTP response code and headers from the
	// server.
	googleapi.ServerResponse `json:"-"`

	// ForceSendFields is a list of field names (e.g. "NextPageToken") to
	// unconditionally include in API requests. By default, fields with
	// empty or default values are omitted from API requests. However, any
	// non-pointer, non-interface field appearing in ForceSendFields will be
	// sent to the server regardless of whether the field is empty or not.
	// This may be used to include empty fields in Patch requests.
	ForceSendFields []string `json:"-"`

	// NullFields is a list of field names (e.g. "NextPageToken") to include
	// in API requests with the JSON null value. By default, fields with
	// empty values are omitted from API requests. However, any field with
	// an empty value appearing in NullFields will be sent to the server as
	// null. It is an error if a field in this list has a non-empty value.
	// This may be used to include null fields in Patch requests.
	NullFields []string `json:"-"`
}

func (s *ListProvisioningQuotasResponse) MarshalJSON() ([]byte, error) {
	type NoMethod ListProvisioningQuotasResponse
	raw := NoMethod(*s)
	return gensupport.MarshalJSON(raw, s.ForceSendFields, s.NullFields)
}

// LunRange: A LUN range.
type LunRange struct {
	// Quantity: Number of LUNs to create.
	Quantity int64 `json:"quantity,omitempty"`

	// SizeGb: The requested size of each LUN, in GB.
	SizeGb int64 `json:"sizeGb,omitempty"`

	// ForceSendFields is a list of field names (e.g. "Quantity") to
	// unconditionally include in API requests. By default, fields with
	// empty or default values are omitted from API requests. However, any
	// non-pointer, non-interface field appearing in ForceSendFields will be
	// sent to the server regardless of whether the field is empty or not.
	// This may be used to include empty fields in Patch requests.
	ForceSendFields []string `json:"-"`

	// NullFields is a list of field names (e.g. "Quantity") to include in
	// API requests with the JSON null value. By default, fields with empty
	// values are omitted from API requests. However, any field with an
	// empty value appearing in NullFields will be sent to the server as
	// null. It is an error if a field in this list has a non-empty value.
	// This may be used to include null fields in Patch requests.
	NullFields []string `json:"-"`
}

func (s *LunRange) MarshalJSON() ([]byte, error) {
	type NoMethod LunRange
	raw := NoMethod(*s)
	return gensupport.MarshalJSON(raw, s.ForceSendFields, s.NullFields)
}

// NetworkAddress: A network.
type NetworkAddress struct {
	// Address: IP address to be assigned to the server.
	Address string `json:"address,omitempty"`

	// NetworkId: Id of the network to use, within the same
	// ProvisioningConfig request.
	NetworkId string `json:"networkId,omitempty"`

	// ForceSendFields is a list of field names (e.g. "Address") to
	// unconditionally include in API requests. By default, fields with
	// empty or default values are omitted from API requests. However, any
	// non-pointer, non-interface field appearing in ForceSendFields will be
	// sent to the server regardless of whether the field is empty or not.
	// This may be used to include empty fields in Patch requests.
	ForceSendFields []string `json:"-"`

	// NullFields is a list of field names (e.g. "Address") to include in
	// API requests with the JSON null value. By default, fields with empty
	// values are omitted from API requests. However, any field with an
	// empty value appearing in NullFields will be sent to the server as
	// null. It is an error if a field in this list has a non-empty value.
	// This may be used to include null fields in Patch requests.
	NullFields []string `json:"-"`
}

func (s *NetworkAddress) MarshalJSON() ([]byte, error) {
	type NoMethod NetworkAddress
	raw := NoMethod(*s)
	return gensupport.MarshalJSON(raw, s.ForceSendFields, s.NullFields)
}

// NetworkConfig: Configuration parameters for a new network.
type NetworkConfig struct {
	// Bandwidth: Interconnect bandwidth. Set only when type is CLIENT.
	//
	// Possible values:
	//   "BANDWIDTH_UNSPECIFIED" - Unspecified value.
	//   "BW_1_GBPS" - 1 Gbps.
	//   "BW_2_GBPS" - 2 Gbps.
	//   "BW_5_GBPS" - 5 Gbps.
	//   "BW_10_GBPS" - 10 Gbps.
	Bandwidth string `json:"bandwidth,omitempty"`

	// Cidr: CIDR range of the network.
	Cidr string `json:"cidr,omitempty"`

	// Id: A transient unique identifier to identify a volume within an
	// ProvisioningConfig request.
	Id string `json:"id,omitempty"`

	// Location: Location where to deploy the network.
	Location string `json:"location,omitempty"`

	// ServiceCidr: Service CIDR, if any.
	//
	// Possible values:
	//   "SERVICE_CIDR_UNSPECIFIED" - Unspecified value.
	//   "DISABLED" - Services are disabled for the given network.
	//   "HIGH_26" - Use the highest /26 block of the network to host
	// services.
	//   "HIGH_27" - Use the highest /27 block of the network to host
	// services.
	//   "HIGH_28" - Use the highest /28 block of the network to host
	// services.
	ServiceCidr string `json:"serviceCidr,omitempty"`

	// Type: The type of this network.
	//
	// Possible values:
	//   "TYPE_UNSPECIFIED" - Unspecified value.
	//   "CLIENT" - Client network, that is a network peered to a GCP VPC.
	//   "PRIVATE" - Private network, that is a network local to the BMS
	// POD.
	Type string `json:"type,omitempty"`

	// UserNote: User note field, it can be used by customers to add
	// additional information for the BMS Ops team (b/194021617).
	UserNote string `json:"userNote,omitempty"`

	// VlanAttachments: List of VLAN attachments. As of now there are always
	// 2 attachments, but it is going to change in the future (multi vlan).
	VlanAttachments []*VlanAttachment `json:"vlanAttachments,omitempty"`

	// ForceSendFields is a list of field names (e.g. "Bandwidth") to
	// unconditionally include in API requests. By default, fields with
	// empty or default values are omitted from API requests. However, any
	// non-pointer, non-interface field appearing in ForceSendFields will be
	// sent to the server regardless of whether the field is empty or not.
	// This may be used to include empty fields in Patch requests.
	ForceSendFields []string `json:"-"`

	// NullFields is a list of field names (e.g. "Bandwidth") to include in
	// API requests with the JSON null value. By default, fields with empty
	// values are omitted from API requests. However, any field with an
	// empty value appearing in NullFields will be sent to the server as
	// null. It is an error if a field in this list has a non-empty value.
	// This may be used to include null fields in Patch requests.
	NullFields []string `json:"-"`
}

func (s *NetworkConfig) MarshalJSON() ([]byte, error) {
	type NoMethod NetworkConfig
	raw := NoMethod(*s)
	return gensupport.MarshalJSON(raw, s.ForceSendFields, s.NullFields)
}

// NfsExport: A NFS export entry.
type NfsExport struct {
	// AllowDev: Allow dev.
	AllowDev bool `json:"allowDev,omitempty"`

	// AllowSuid: Allow the setuid flag.
	AllowSuid bool `json:"allowSuid,omitempty"`

	// Cidr: A CIDR range.
	Cidr string `json:"cidr,omitempty"`

	// MachineId: Either a single machine, identified by an ID, or a
	// comma-separated list of machine IDs.
	MachineId string `json:"machineId,omitempty"`

	// NetworkId: Network to use to publish the export.
	NetworkId string `json:"networkId,omitempty"`

	// NoRootSquash: Disable root squashing.
	NoRootSquash bool `json:"noRootSquash,omitempty"`

	// Permissions: Export permissions.
	//
	// Possible values:
	//   "PERMISSIONS_UNSPECIFIED" - Unspecified value.
	//   "READ_ONLY" - Read-only permission.
	//   "READ_WRITE" - Read-write permission.
	Permissions string `json:"permissions,omitempty"`

	// ForceSendFields is a list of field names (e.g. "AllowDev") to
	// unconditionally include in API requests. By default, fields with
	// empty or default values are omitted from API requests. However, any
	// non-pointer, non-interface field appearing in ForceSendFields will be
	// sent to the server regardless of whether the field is empty or not.
	// This may be used to include empty fields in Patch requests.
	ForceSendFields []string `json:"-"`

	// NullFields is a list of field names (e.g. "AllowDev") to include in
	// API requests with the JSON null value. By default, fields with empty
	// values are omitted from API requests. However, any field with an
	// empty value appearing in NullFields will be sent to the server as
	// null. It is an error if a field in this list has a non-empty value.
	// This may be used to include null fields in Patch requests.
	NullFields []string `json:"-"`
}

func (s *NfsExport) MarshalJSON() ([]byte, error) {
	type NoMethod NfsExport
	raw := NoMethod(*s)
	return gensupport.MarshalJSON(raw, s.ForceSendFields, s.NullFields)
}

// ProvisioningConfig: An provisioning configuration.
type ProvisioningConfig struct {
	// Instances: Instances to be created.
	Instances []*InstanceConfig `json:"instances,omitempty"`

	// Networks: Networks to be created.
	Networks []*NetworkConfig `json:"networks,omitempty"`

	// TicketId: A reference to track the request.
	TicketId string `json:"ticketId,omitempty"`

	// Volumes: Volumes to be created.
	Volumes []*VolumeConfig `json:"volumes,omitempty"`

	// ServerResponse contains the HTTP response code and headers from the
	// server.
	googleapi.ServerResponse `json:"-"`

	// ForceSendFields is a list of field names (e.g. "Instances") to
	// unconditionally include in API requests. By default, fields with
	// empty or default values are omitted from API requests. However, any
	// non-pointer, non-interface field appearing in ForceSendFields will be
	// sent to the server regardless of whether the field is empty or not.
	// This may be used to include empty fields in Patch requests.
	ForceSendFields []string `json:"-"`

	// NullFields is a list of field names (e.g. "Instances") to include in
	// API requests with the JSON null value. By default, fields with empty
	// values are omitted from API requests. However, any field with an
	// empty value appearing in NullFields will be sent to the server as
	// null. It is an error if a field in this list has a non-empty value.
	// This may be used to include null fields in Patch requests.
	NullFields []string `json:"-"`
}

func (s *ProvisioningConfig) MarshalJSON() ([]byte, error) {
	type NoMethod ProvisioningConfig
	raw := NoMethod(*s)
	return gensupport.MarshalJSON(raw, s.ForceSendFields, s.NullFields)
}

// ProvisioningQuota: A provisioning quota for a given project.
type ProvisioningQuota struct {
	// InstanceQuota: Instance quota.
	InstanceQuota *InstanceQuota `json:"instanceQuota,omitempty"`

	// ForceSendFields is a list of field names (e.g. "InstanceQuota") to
	// unconditionally include in API requests. By default, fields with
	// empty or default values are omitted from API requests. However, any
	// non-pointer, non-interface field appearing in ForceSendFields will be
	// sent to the server regardless of whether the field is empty or not.
	// This may be used to include empty fields in Patch requests.
	ForceSendFields []string `json:"-"`

	// NullFields is a list of field names (e.g. "InstanceQuota") to include
	// in API requests with the JSON null value. By default, fields with
	// empty values are omitted from API requests. However, any field with
	// an empty value appearing in NullFields will be sent to the server as
	// null. It is an error if a field in this list has a non-empty value.
	// This may be used to include null fields in Patch requests.
	NullFields []string `json:"-"`
}

func (s *ProvisioningQuota) MarshalJSON() ([]byte, error) {
	type NoMethod ProvisioningQuota
	raw := NoMethod(*s)
	return gensupport.MarshalJSON(raw, s.ForceSendFields, s.NullFields)
}

// SubmitProvisioningConfigRequest: Request for
// SubmitProvisioningConfig.
type SubmitProvisioningConfigRequest struct {
	// Email: Optional. Email provided to send a confirmation with
	// provisioning config to.
	Email string `json:"email,omitempty"`

	// ProvisioningConfig: Required. The ProvisioningConfig to submit.
	ProvisioningConfig *ProvisioningConfig `json:"provisioningConfig,omitempty"`

	// ForceSendFields is a list of field names (e.g. "Email") to
	// unconditionally include in API requests. By default, fields with
	// empty or default values are omitted from API requests. However, any
	// non-pointer, non-interface field appearing in ForceSendFields will be
	// sent to the server regardless of whether the field is empty or not.
	// This may be used to include empty fields in Patch requests.
	ForceSendFields []string `json:"-"`

	// NullFields is a list of field names (e.g. "Email") to include in API
	// requests with the JSON null value. By default, fields with empty
	// values are omitted from API requests. However, any field with an
	// empty value appearing in NullFields will be sent to the server as
	// null. It is an error if a field in this list has a non-empty value.
	// This may be used to include null fields in Patch requests.
	NullFields []string `json:"-"`
}

func (s *SubmitProvisioningConfigRequest) MarshalJSON() ([]byte, error) {
	type NoMethod SubmitProvisioningConfigRequest
	raw := NoMethod(*s)
	return gensupport.MarshalJSON(raw, s.ForceSendFields, s.NullFields)
}

// VlanAttachment: A GCP vlan attachment.
type VlanAttachment struct {
	// Id: Identifier of the VLAN attachment.
	Id string `json:"id,omitempty"`

	// PairingKey: Attachment pairing key.
	PairingKey string `json:"pairingKey,omitempty"`

	// ForceSendFields is a list of field names (e.g. "Id") to
	// unconditionally include in API requests. By default, fields with
	// empty or default values are omitted from API requests. However, any
	// non-pointer, non-interface field appearing in ForceSendFields will be
	// sent to the server regardless of whether the field is empty or not.
	// This may be used to include empty fields in Patch requests.
	ForceSendFields []string `json:"-"`

	// NullFields is a list of field names (e.g. "Id") to include in API
	// requests with the JSON null value. By default, fields with empty
	// values are omitted from API requests. However, any field with an
	// empty value appearing in NullFields will be sent to the server as
	// null. It is an error if a field in this list has a non-empty value.
	// This may be used to include null fields in Patch requests.
	NullFields []string `json:"-"`
}

func (s *VlanAttachment) MarshalJSON() ([]byte, error) {
	type NoMethod VlanAttachment
	raw := NoMethod(*s)
	return gensupport.MarshalJSON(raw, s.ForceSendFields, s.NullFields)
}

// VolumeConfig: Configuration parameters for a new volume.
type VolumeConfig struct {
	// Id: A transient unique identifier to identify a volume within an
	// ProvisioningConfig request.
	Id string `json:"id,omitempty"`

	// Location: Location where to deploy the volume.
	Location string `json:"location,omitempty"`

	// LunRanges: LUN ranges to be configured. Set only when protocol is
	// PROTOCOL_FC.
	LunRanges []*LunRange `json:"lunRanges,omitempty"`

	// MachineIds: Machine ids connected to this volume. Set only when
	// protocol is PROTOCOL_FC.
	MachineIds []string `json:"machineIds,omitempty"`

	// NfsExports: NFS exports. Set only when protocol is PROTOCOL_NFS.
	NfsExports []*NfsExport `json:"nfsExports,omitempty"`

	// Protocol: Volume protocol.
	//
	// Possible values:
	//   "PROTOCOL_UNSPECIFIED" - Unspecified value.
	//   "PROTOCOL_FC" - Fibre channel.
	//   "PROTOCOL_NFS" - Network file system.
	Protocol string `json:"protocol,omitempty"`

	// SizeGb: The requested size of this volume, in GB. This will be
	// updated in a later iteration with a generic size field.
	SizeGb int64 `json:"sizeGb,omitempty"`

	// SnapshotsEnabled: Whether snapshots should be enabled.
	SnapshotsEnabled bool `json:"snapshotsEnabled,omitempty"`

	// Type: The type of this Volume.
	//
	// Possible values:
	//   "TYPE_UNSPECIFIED" - The unspecified type.
	//   "FLASH" - This Volume is on flash.
	//   "DISK" - This Volume is on disk.
	Type string `json:"type,omitempty"`

	// UserNote: User note field, it can be used by customers to add
	// additional information for the BMS Ops team (b/194021617).
	UserNote string `json:"userNote,omitempty"`

	// ForceSendFields is a list of field names (e.g. "Id") to
	// unconditionally include in API requests. By default, fields with
	// empty or default values are omitted from API requests. However, any
	// non-pointer, non-interface field appearing in ForceSendFields will be
	// sent to the server regardless of whether the field is empty or not.
	// This may be used to include empty fields in Patch requests.
	ForceSendFields []string `json:"-"`

	// NullFields is a list of field names (e.g. "Id") to include in API
	// requests with the JSON null value. By default, fields with empty
	// values are omitted from API requests. However, any field with an
	// empty value appearing in NullFields will be sent to the server as
	// null. It is an error if a field in this list has a non-empty value.
	// This may be used to include null fields in Patch requests.
	NullFields []string `json:"-"`
}

func (s *VolumeConfig) MarshalJSON() ([]byte, error) {
	type NoMethod VolumeConfig
	raw := NoMethod(*s)
	return gensupport.MarshalJSON(raw, s.ForceSendFields, s.NullFields)
}

// method id "baremetalsolution.projects.locations.submitProvisioningConfig":

type ProjectsLocationsSubmitProvisioningConfigCall struct {
	s                               *Service
	project                         string
	location                        string
	submitprovisioningconfigrequest *SubmitProvisioningConfigRequest
	urlParams_                      gensupport.URLParams
	ctx_                            context.Context
	header_                         http.Header
}

// SubmitProvisioningConfig: Submit a provisiong configuration for a
// given project.
//
// - location: The target location of the provisioning request.
// - project: The target project of the provisioning request.
func (r *ProjectsLocationsService) SubmitProvisioningConfig(project string, location string, submitprovisioningconfigrequest *SubmitProvisioningConfigRequest) *ProjectsLocationsSubmitProvisioningConfigCall {
	c := &ProjectsLocationsSubmitProvisioningConfigCall{s: r.s, urlParams_: make(gensupport.URLParams)}
	c.project = project
	c.location = location
	c.submitprovisioningconfigrequest = submitprovisioningconfigrequest
	return c
}

// Fields allows partial responses to be retrieved. See
// https://developers.google.com/gdata/docs/2.0/basics#PartialResponse
// for more information.
func (c *ProjectsLocationsSubmitProvisioningConfigCall) Fields(s ...googleapi.Field) *ProjectsLocationsSubmitProvisioningConfigCall {
	c.urlParams_.Set("fields", googleapi.CombineFields(s))
	return c
}

// Context sets the context to be used in this call's Do method. Any
// pending HTTP request will be aborted if the provided context is
// canceled.
func (c *ProjectsLocationsSubmitProvisioningConfigCall) Context(ctx context.Context) *ProjectsLocationsSubmitProvisioningConfigCall {
	c.ctx_ = ctx
	return c
}

// Header returns an http.Header that can be modified by the caller to
// add HTTP headers to the request.
func (c *ProjectsLocationsSubmitProvisioningConfigCall) Header() http.Header {
	if c.header_ == nil {
		c.header_ = make(http.Header)
	}
	return c.header_
}

func (c *ProjectsLocationsSubmitProvisioningConfigCall) doRequest(alt string) (*http.Response, error) {
	reqHeaders := make(http.Header)
	reqHeaders.Set("x-goog-api-client", "gl-go/"+gensupport.GoVersion()+" gdcl/20211026")
	for k, v := range c.header_ {
		reqHeaders[k] = v
	}
	reqHeaders.Set("User-Agent", c.s.userAgent())
	var body io.Reader = nil
	body, err := googleapi.WithoutDataWrapper.JSONReader(c.submitprovisioningconfigrequest)
	if err != nil {
		return nil, err
	}
	reqHeaders.Set("Content-Type", "application/json")
	c.urlParams_.Set("alt", alt)
	c.urlParams_.Set("prettyPrint", "false")
	urls := googleapi.ResolveRelative(c.s.BasePath, "v1alpha1/{+project}/{+location}:submitProvisioningConfig")
	urls += "?" + c.urlParams_.Encode()
	req, err := http.NewRequest("POST", urls, body)
	if err != nil {
		return nil, err
	}
	req.Header = reqHeaders
	googleapi.Expand(req.URL, map[string]string{
		"project":  c.project,
		"location": c.location,
	})
	return gensupport.SendRequest(c.ctx_, c.s.client, req)
}

// Do executes the "baremetalsolution.projects.locations.submitProvisioningConfig" call.
// Exactly one of *ProvisioningConfig or error will be non-nil. Any
// non-2xx status code is an error. Response headers are in either
// *ProvisioningConfig.ServerResponse.Header or (if a response was
// returned at all) in error.(*googleapi.Error).Header. Use
// googleapi.IsNotModified to check whether the returned error was
// because http.StatusNotModified was returned.
func (c *ProjectsLocationsSubmitProvisioningConfigCall) Do(opts ...googleapi.CallOption) (*ProvisioningConfig, error) {
	gensupport.SetOptions(c.urlParams_, opts...)
	res, err := c.doRequest("json")
	if res != nil && res.StatusCode == http.StatusNotModified {
		if res.Body != nil {
			res.Body.Close()
		}
		return nil, &googleapi.Error{
			Code:   res.StatusCode,
			Header: res.Header,
		}
	}
	if err != nil {
		return nil, err
	}
	defer googleapi.CloseBody(res)
	if err := googleapi.CheckResponse(res); err != nil {
		return nil, err
	}
	ret := &ProvisioningConfig{
		ServerResponse: googleapi.ServerResponse{
			Header:         res.Header,
			HTTPStatusCode: res.StatusCode,
		},
	}
	target := &ret
	if err := gensupport.DecodeResponse(target, res); err != nil {
		return nil, err
	}
	return ret, nil
	// {
	//   "description": "Submit a provisiong configuration for a given project.",
	//   "flatPath": "v1alpha1/projects/{projectsId}/locations/{locationsId}:submitProvisioningConfig",
	//   "httpMethod": "POST",
	//   "id": "baremetalsolution.projects.locations.submitProvisioningConfig",
	//   "parameterOrder": [
	//     "project",
	//     "location"
	//   ],
	//   "parameters": {
	//     "location": {
	//       "description": "Required. The target location of the provisioning request.",
	//       "location": "path",
	//       "pattern": "^locations/[^/]+$",
	//       "required": true,
	//       "type": "string"
	//     },
	//     "project": {
	//       "description": "Required. The target project of the provisioning request.",
	//       "location": "path",
	//       "pattern": "^projects/[^/]+$",
	//       "required": true,
	//       "type": "string"
	//     }
	//   },
	//   "path": "v1alpha1/{+project}/{+location}:submitProvisioningConfig",
	//   "request": {
	//     "$ref": "SubmitProvisioningConfigRequest"
	//   },
	//   "response": {
	//     "$ref": "ProvisioningConfig"
	//   },
	//   "scopes": [
	//     "https://www.googleapis.com/auth/cloud-platform"
	//   ]
	// }

}

// method id "baremetalsolution.projects.provisioningQuotas.list":

type ProjectsProvisioningQuotasListCall struct {
	s            *Service
	parent       string
	urlParams_   gensupport.URLParams
	ifNoneMatch_ string
	ctx_         context.Context
	header_      http.Header
}

// List: List the budget details to provision resources on a given
// project.
//
// - parent: The parent project containing the provisioning quotas.
func (r *ProjectsProvisioningQuotasService) List(parent string) *ProjectsProvisioningQuotasListCall {
	c := &ProjectsProvisioningQuotasListCall{s: r.s, urlParams_: make(gensupport.URLParams)}
	c.parent = parent
	return c
}

// PageSize sets the optional parameter "pageSize": The maximum number
// of items to return.
func (c *ProjectsProvisioningQuotasListCall) PageSize(pageSize int64) *ProjectsProvisioningQuotasListCall {
	c.urlParams_.Set("pageSize", fmt.Sprint(pageSize))
	return c
}

// PageToken sets the optional parameter "pageToken": The
// next_page_token value returned from a previous List request, if any.
func (c *ProjectsProvisioningQuotasListCall) PageToken(pageToken string) *ProjectsProvisioningQuotasListCall {
	c.urlParams_.Set("pageToken", pageToken)
	return c
}

// Fields allows partial responses to be retrieved. See
// https://developers.google.com/gdata/docs/2.0/basics#PartialResponse
// for more information.
func (c *ProjectsProvisioningQuotasListCall) Fields(s ...googleapi.Field) *ProjectsProvisioningQuotasListCall {
	c.urlParams_.Set("fields", googleapi.CombineFields(s))
	return c
}

// IfNoneMatch sets the optional parameter which makes the operation
// fail if the object's ETag matches the given value. This is useful for
// getting updates only after the object has changed since the last
// request. Use googleapi.IsNotModified to check whether the response
// error from Do is the result of In-None-Match.
func (c *ProjectsProvisioningQuotasListCall) IfNoneMatch(entityTag string) *ProjectsProvisioningQuotasListCall {
	c.ifNoneMatch_ = entityTag
	return c
}

// Context sets the context to be used in this call's Do method. Any
// pending HTTP request will be aborted if the provided context is
// canceled.
func (c *ProjectsProvisioningQuotasListCall) Context(ctx context.Context) *ProjectsProvisioningQuotasListCall {
	c.ctx_ = ctx
	return c
}

// Header returns an http.Header that can be modified by the caller to
// add HTTP headers to the request.
func (c *ProjectsProvisioningQuotasListCall) Header() http.Header {
	if c.header_ == nil {
		c.header_ = make(http.Header)
	}
	return c.header_
}

func (c *ProjectsProvisioningQuotasListCall) doRequest(alt string) (*http.Response, error) {
	reqHeaders := make(http.Header)
	reqHeaders.Set("x-goog-api-client", "gl-go/"+gensupport.GoVersion()+" gdcl/20211026")
	for k, v := range c.header_ {
		reqHeaders[k] = v
	}
	reqHeaders.Set("User-Agent", c.s.userAgent())
	if c.ifNoneMatch_ != "" {
		reqHeaders.Set("If-None-Match", c.ifNoneMatch_)
	}
	var body io.Reader = nil
	c.urlParams_.Set("alt", alt)
	c.urlParams_.Set("prettyPrint", "false")
	urls := googleapi.ResolveRelative(c.s.BasePath, "v1alpha1/{+parent}/provisioningQuotas")
	urls += "?" + c.urlParams_.Encode()
	req, err := http.NewRequest("GET", urls, body)
	if err != nil {
		return nil, err
	}
	req.Header = reqHeaders
	googleapi.Expand(req.URL, map[string]string{
		"parent": c.parent,
	})
	return gensupport.SendRequest(c.ctx_, c.s.client, req)
}

// Do executes the "baremetalsolution.projects.provisioningQuotas.list" call.
// Exactly one of *ListProvisioningQuotasResponse or error will be
// non-nil. Any non-2xx status code is an error. Response headers are in
// either *ListProvisioningQuotasResponse.ServerResponse.Header or (if a
// response was returned at all) in error.(*googleapi.Error).Header. Use
// googleapi.IsNotModified to check whether the returned error was
// because http.StatusNotModified was returned.
func (c *ProjectsProvisioningQuotasListCall) Do(opts ...googleapi.CallOption) (*ListProvisioningQuotasResponse, error) {
	gensupport.SetOptions(c.urlParams_, opts...)
	res, err := c.doRequest("json")
	if res != nil && res.StatusCode == http.StatusNotModified {
		if res.Body != nil {
			res.Body.Close()
		}
		return nil, &googleapi.Error{
			Code:   res.StatusCode,
			Header: res.Header,
		}
	}
	if err != nil {
		return nil, err
	}
	defer googleapi.CloseBody(res)
	if err := googleapi.CheckResponse(res); err != nil {
		return nil, err
	}
	ret := &ListProvisioningQuotasResponse{
		ServerResponse: googleapi.ServerResponse{
			Header:         res.Header,
			HTTPStatusCode: res.StatusCode,
		},
	}
	target := &ret
	if err := gensupport.DecodeResponse(target, res); err != nil {
		return nil, err
	}
	return ret, nil
	// {
	//   "description": "List the budget details to provision resources on a given project.",
	//   "flatPath": "v1alpha1/projects/{projectsId}/provisioningQuotas",
	//   "httpMethod": "GET",
	//   "id": "baremetalsolution.projects.provisioningQuotas.list",
	//   "parameterOrder": [
	//     "parent"
	//   ],
	//   "parameters": {
	//     "pageSize": {
	//       "description": "The maximum number of items to return.",
	//       "format": "int32",
	//       "location": "query",
	//       "type": "integer"
	//     },
	//     "pageToken": {
	//       "description": "The next_page_token value returned from a previous List request, if any.",
	//       "location": "query",
	//       "type": "string"
	//     },
	//     "parent": {
	//       "description": "Required. The parent project containing the provisioning quotas.",
	//       "location": "path",
	//       "pattern": "^projects/[^/]+$",
	//       "required": true,
	//       "type": "string"
	//     }
	//   },
	//   "path": "v1alpha1/{+parent}/provisioningQuotas",
	//   "response": {
	//     "$ref": "ListProvisioningQuotasResponse"
	//   },
	//   "scopes": [
	//     "https://www.googleapis.com/auth/cloud-platform"
	//   ]
	// }

}

// Pages invokes f for each page of results.
// A non-nil error returned from f will halt the iteration.
// The provided context supersedes any context provided to the Context method.
func (c *ProjectsProvisioningQuotasListCall) Pages(ctx context.Context, f func(*ListProvisioningQuotasResponse) error) error {
	c.ctx_ = ctx
	defer c.PageToken(c.urlParams_.Get("pageToken")) // reset paging to original point
	for {
		x, err := c.Do()
		if err != nil {
			return err
		}
		if err := f(x); err != nil {
			return err
		}
		if x.NextPageToken == "" {
			return nil
		}
		c.PageToken(x.NextPageToken)
	}
}
