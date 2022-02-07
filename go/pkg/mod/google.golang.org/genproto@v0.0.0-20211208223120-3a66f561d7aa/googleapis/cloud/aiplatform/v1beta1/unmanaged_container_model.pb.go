// Copyright 2021 Google LLC
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

// Code generated by protoc-gen-go. DO NOT EDIT.
// versions:
// 	protoc-gen-go v1.26.0
// 	protoc        v3.12.2
// source: google/cloud/aiplatform/v1beta1/unmanaged_container_model.proto

package aiplatform

import (
	reflect "reflect"
	sync "sync"

	_ "google.golang.org/genproto/googleapis/api/annotations"
	protoreflect "google.golang.org/protobuf/reflect/protoreflect"
	protoimpl "google.golang.org/protobuf/runtime/protoimpl"
)

const (
	// Verify that this generated code is sufficiently up-to-date.
	_ = protoimpl.EnforceVersion(20 - protoimpl.MinVersion)
	// Verify that runtime/protoimpl is sufficiently up-to-date.
	_ = protoimpl.EnforceVersion(protoimpl.MaxVersion - 20)
)

// Contains model information necessary to perform batch prediction without
// requiring a full model import.
type UnmanagedContainerModel struct {
	state         protoimpl.MessageState
	sizeCache     protoimpl.SizeCache
	unknownFields protoimpl.UnknownFields

	// The path to the directory containing the Model artifact and any of its
	// supporting files.
	ArtifactUri string `protobuf:"bytes,1,opt,name=artifact_uri,json=artifactUri,proto3" json:"artifact_uri,omitempty"`
	// Contains the schemata used in Model's predictions and explanations
	PredictSchemata *PredictSchemata `protobuf:"bytes,2,opt,name=predict_schemata,json=predictSchemata,proto3" json:"predict_schemata,omitempty"`
	// Input only. The specification of the container that is to be used when deploying
	// this Model.
	ContainerSpec *ModelContainerSpec `protobuf:"bytes,3,opt,name=container_spec,json=containerSpec,proto3" json:"container_spec,omitempty"`
}

func (x *UnmanagedContainerModel) Reset() {
	*x = UnmanagedContainerModel{}
	if protoimpl.UnsafeEnabled {
		mi := &file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_msgTypes[0]
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		ms.StoreMessageInfo(mi)
	}
}

func (x *UnmanagedContainerModel) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*UnmanagedContainerModel) ProtoMessage() {}

func (x *UnmanagedContainerModel) ProtoReflect() protoreflect.Message {
	mi := &file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_msgTypes[0]
	if protoimpl.UnsafeEnabled && x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use UnmanagedContainerModel.ProtoReflect.Descriptor instead.
func (*UnmanagedContainerModel) Descriptor() ([]byte, []int) {
	return file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_rawDescGZIP(), []int{0}
}

func (x *UnmanagedContainerModel) GetArtifactUri() string {
	if x != nil {
		return x.ArtifactUri
	}
	return ""
}

func (x *UnmanagedContainerModel) GetPredictSchemata() *PredictSchemata {
	if x != nil {
		return x.PredictSchemata
	}
	return nil
}

func (x *UnmanagedContainerModel) GetContainerSpec() *ModelContainerSpec {
	if x != nil {
		return x.ContainerSpec
	}
	return nil
}

var File_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto protoreflect.FileDescriptor

var file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_rawDesc = []byte{
	0x0a, 0x3f, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2f, 0x63, 0x6c, 0x6f, 0x75, 0x64, 0x2f, 0x61,
	0x69, 0x70, 0x6c, 0x61, 0x74, 0x66, 0x6f, 0x72, 0x6d, 0x2f, 0x76, 0x31, 0x62, 0x65, 0x74, 0x61,
	0x31, 0x2f, 0x75, 0x6e, 0x6d, 0x61, 0x6e, 0x61, 0x67, 0x65, 0x64, 0x5f, 0x63, 0x6f, 0x6e, 0x74,
	0x61, 0x69, 0x6e, 0x65, 0x72, 0x5f, 0x6d, 0x6f, 0x64, 0x65, 0x6c, 0x2e, 0x70, 0x72, 0x6f, 0x74,
	0x6f, 0x12, 0x1f, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2e, 0x63, 0x6c, 0x6f, 0x75, 0x64, 0x2e,
	0x61, 0x69, 0x70, 0x6c, 0x61, 0x74, 0x66, 0x6f, 0x72, 0x6d, 0x2e, 0x76, 0x31, 0x62, 0x65, 0x74,
	0x61, 0x31, 0x1a, 0x1f, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2f, 0x61, 0x70, 0x69, 0x2f, 0x66,
	0x69, 0x65, 0x6c, 0x64, 0x5f, 0x62, 0x65, 0x68, 0x61, 0x76, 0x69, 0x6f, 0x72, 0x2e, 0x70, 0x72,
	0x6f, 0x74, 0x6f, 0x1a, 0x2b, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2f, 0x63, 0x6c, 0x6f, 0x75,
	0x64, 0x2f, 0x61, 0x69, 0x70, 0x6c, 0x61, 0x74, 0x66, 0x6f, 0x72, 0x6d, 0x2f, 0x76, 0x31, 0x62,
	0x65, 0x74, 0x61, 0x31, 0x2f, 0x6d, 0x6f, 0x64, 0x65, 0x6c, 0x2e, 0x70, 0x72, 0x6f, 0x74, 0x6f,
	0x1a, 0x1c, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2f, 0x61, 0x70, 0x69, 0x2f, 0x61, 0x6e, 0x6e,
	0x6f, 0x74, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x73, 0x2e, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x22, 0xfa,
	0x01, 0x0a, 0x17, 0x55, 0x6e, 0x6d, 0x61, 0x6e, 0x61, 0x67, 0x65, 0x64, 0x43, 0x6f, 0x6e, 0x74,
	0x61, 0x69, 0x6e, 0x65, 0x72, 0x4d, 0x6f, 0x64, 0x65, 0x6c, 0x12, 0x21, 0x0a, 0x0c, 0x61, 0x72,
	0x74, 0x69, 0x66, 0x61, 0x63, 0x74, 0x5f, 0x75, 0x72, 0x69, 0x18, 0x01, 0x20, 0x01, 0x28, 0x09,
	0x52, 0x0b, 0x61, 0x72, 0x74, 0x69, 0x66, 0x61, 0x63, 0x74, 0x55, 0x72, 0x69, 0x12, 0x5b, 0x0a,
	0x10, 0x70, 0x72, 0x65, 0x64, 0x69, 0x63, 0x74, 0x5f, 0x73, 0x63, 0x68, 0x65, 0x6d, 0x61, 0x74,
	0x61, 0x18, 0x02, 0x20, 0x01, 0x28, 0x0b, 0x32, 0x30, 0x2e, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65,
	0x2e, 0x63, 0x6c, 0x6f, 0x75, 0x64, 0x2e, 0x61, 0x69, 0x70, 0x6c, 0x61, 0x74, 0x66, 0x6f, 0x72,
	0x6d, 0x2e, 0x76, 0x31, 0x62, 0x65, 0x74, 0x61, 0x31, 0x2e, 0x50, 0x72, 0x65, 0x64, 0x69, 0x63,
	0x74, 0x53, 0x63, 0x68, 0x65, 0x6d, 0x61, 0x74, 0x61, 0x52, 0x0f, 0x70, 0x72, 0x65, 0x64, 0x69,
	0x63, 0x74, 0x53, 0x63, 0x68, 0x65, 0x6d, 0x61, 0x74, 0x61, 0x12, 0x5f, 0x0a, 0x0e, 0x63, 0x6f,
	0x6e, 0x74, 0x61, 0x69, 0x6e, 0x65, 0x72, 0x5f, 0x73, 0x70, 0x65, 0x63, 0x18, 0x03, 0x20, 0x01,
	0x28, 0x0b, 0x32, 0x33, 0x2e, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2e, 0x63, 0x6c, 0x6f, 0x75,
	0x64, 0x2e, 0x61, 0x69, 0x70, 0x6c, 0x61, 0x74, 0x66, 0x6f, 0x72, 0x6d, 0x2e, 0x76, 0x31, 0x62,
	0x65, 0x74, 0x61, 0x31, 0x2e, 0x4d, 0x6f, 0x64, 0x65, 0x6c, 0x43, 0x6f, 0x6e, 0x74, 0x61, 0x69,
	0x6e, 0x65, 0x72, 0x53, 0x70, 0x65, 0x63, 0x42, 0x03, 0xe0, 0x41, 0x04, 0x52, 0x0d, 0x63, 0x6f,
	0x6e, 0x74, 0x61, 0x69, 0x6e, 0x65, 0x72, 0x53, 0x70, 0x65, 0x63, 0x42, 0xf9, 0x01, 0x0a, 0x23,
	0x63, 0x6f, 0x6d, 0x2e, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2e, 0x63, 0x6c, 0x6f, 0x75, 0x64,
	0x2e, 0x61, 0x69, 0x70, 0x6c, 0x61, 0x74, 0x66, 0x6f, 0x72, 0x6d, 0x2e, 0x76, 0x31, 0x62, 0x65,
	0x74, 0x61, 0x31, 0x42, 0x1c, 0x55, 0x6e, 0x6d, 0x61, 0x6e, 0x61, 0x67, 0x65, 0x64, 0x43, 0x6f,
	0x6e, 0x74, 0x61, 0x69, 0x6e, 0x65, 0x72, 0x4d, 0x6f, 0x64, 0x65, 0x6c, 0x50, 0x72, 0x6f, 0x74,
	0x6f, 0x50, 0x01, 0x5a, 0x49, 0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2e, 0x67, 0x6f, 0x6c, 0x61,
	0x6e, 0x67, 0x2e, 0x6f, 0x72, 0x67, 0x2f, 0x67, 0x65, 0x6e, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x2f,
	0x67, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x61, 0x70, 0x69, 0x73, 0x2f, 0x63, 0x6c, 0x6f, 0x75, 0x64,
	0x2f, 0x61, 0x69, 0x70, 0x6c, 0x61, 0x74, 0x66, 0x6f, 0x72, 0x6d, 0x2f, 0x76, 0x31, 0x62, 0x65,
	0x74, 0x61, 0x31, 0x3b, 0x61, 0x69, 0x70, 0x6c, 0x61, 0x74, 0x66, 0x6f, 0x72, 0x6d, 0xaa, 0x02,
	0x1f, 0x47, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x2e, 0x43, 0x6c, 0x6f, 0x75, 0x64, 0x2e, 0x41, 0x49,
	0x50, 0x6c, 0x61, 0x74, 0x66, 0x6f, 0x72, 0x6d, 0x2e, 0x56, 0x31, 0x42, 0x65, 0x74, 0x61, 0x31,
	0xca, 0x02, 0x1f, 0x47, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x5c, 0x43, 0x6c, 0x6f, 0x75, 0x64, 0x5c,
	0x41, 0x49, 0x50, 0x6c, 0x61, 0x74, 0x66, 0x6f, 0x72, 0x6d, 0x5c, 0x56, 0x31, 0x62, 0x65, 0x74,
	0x61, 0x31, 0xea, 0x02, 0x22, 0x47, 0x6f, 0x6f, 0x67, 0x6c, 0x65, 0x3a, 0x3a, 0x43, 0x6c, 0x6f,
	0x75, 0x64, 0x3a, 0x3a, 0x41, 0x49, 0x50, 0x6c, 0x61, 0x74, 0x66, 0x6f, 0x72, 0x6d, 0x3a, 0x3a,
	0x56, 0x31, 0x62, 0x65, 0x74, 0x61, 0x31, 0x62, 0x06, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x33,
}

var (
	file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_rawDescOnce sync.Once
	file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_rawDescData = file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_rawDesc
)

func file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_rawDescGZIP() []byte {
	file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_rawDescOnce.Do(func() {
		file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_rawDescData = protoimpl.X.CompressGZIP(file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_rawDescData)
	})
	return file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_rawDescData
}

var file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_msgTypes = make([]protoimpl.MessageInfo, 1)
var file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_goTypes = []interface{}{
	(*UnmanagedContainerModel)(nil), // 0: google.cloud.aiplatform.v1beta1.UnmanagedContainerModel
	(*PredictSchemata)(nil),         // 1: google.cloud.aiplatform.v1beta1.PredictSchemata
	(*ModelContainerSpec)(nil),      // 2: google.cloud.aiplatform.v1beta1.ModelContainerSpec
}
var file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_depIdxs = []int32{
	1, // 0: google.cloud.aiplatform.v1beta1.UnmanagedContainerModel.predict_schemata:type_name -> google.cloud.aiplatform.v1beta1.PredictSchemata
	2, // 1: google.cloud.aiplatform.v1beta1.UnmanagedContainerModel.container_spec:type_name -> google.cloud.aiplatform.v1beta1.ModelContainerSpec
	2, // [2:2] is the sub-list for method output_type
	2, // [2:2] is the sub-list for method input_type
	2, // [2:2] is the sub-list for extension type_name
	2, // [2:2] is the sub-list for extension extendee
	0, // [0:2] is the sub-list for field type_name
}

func init() { file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_init() }
func file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_init() {
	if File_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto != nil {
		return
	}
	file_google_cloud_aiplatform_v1beta1_model_proto_init()
	if !protoimpl.UnsafeEnabled {
		file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_msgTypes[0].Exporter = func(v interface{}, i int) interface{} {
			switch v := v.(*UnmanagedContainerModel); i {
			case 0:
				return &v.state
			case 1:
				return &v.sizeCache
			case 2:
				return &v.unknownFields
			default:
				return nil
			}
		}
	}
	type x struct{}
	out := protoimpl.TypeBuilder{
		File: protoimpl.DescBuilder{
			GoPackagePath: reflect.TypeOf(x{}).PkgPath(),
			RawDescriptor: file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_rawDesc,
			NumEnums:      0,
			NumMessages:   1,
			NumExtensions: 0,
			NumServices:   0,
		},
		GoTypes:           file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_goTypes,
		DependencyIndexes: file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_depIdxs,
		MessageInfos:      file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_msgTypes,
	}.Build()
	File_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto = out.File
	file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_rawDesc = nil
	file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_goTypes = nil
	file_google_cloud_aiplatform_v1beta1_unmanaged_container_model_proto_depIdxs = nil
}
