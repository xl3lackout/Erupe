// Code generated by protoc-gen-validate. DO NOT EDIT.
// source: contrib/envoy/extensions/filters/network/mysql_proxy/v3/mysql_proxy.proto

package envoy_extensions_filters_network_mysql_proxy_v3

import (
	"bytes"
	"errors"
	"fmt"
	"net"
	"net/mail"
	"net/url"
	"regexp"
	"sort"
	"strings"
	"time"
	"unicode/utf8"

	"google.golang.org/protobuf/types/known/anypb"
)

// ensure the imports are used
var (
	_ = bytes.MinRead
	_ = errors.New("")
	_ = fmt.Print
	_ = utf8.UTFMax
	_ = (*regexp.Regexp)(nil)
	_ = (*strings.Reader)(nil)
	_ = net.IPv4len
	_ = time.Duration(0)
	_ = (*url.URL)(nil)
	_ = (*mail.Address)(nil)
	_ = anypb.Any{}
	_ = sort.Sort
)

// Validate checks the field values on MySQLProxy with the rules defined in the
// proto definition for this message. If any rules are violated, the first
// error encountered is returned, or nil if there are no violations.
func (m *MySQLProxy) Validate() error {
	return m.validate(false)
}

// ValidateAll checks the field values on MySQLProxy with the rules defined in
// the proto definition for this message. If any rules are violated, the
// result is a list of violation errors wrapped in MySQLProxyMultiError, or
// nil if none found.
func (m *MySQLProxy) ValidateAll() error {
	return m.validate(true)
}

func (m *MySQLProxy) validate(all bool) error {
	if m == nil {
		return nil
	}

	var errors []error

	if utf8.RuneCountInString(m.GetStatPrefix()) < 1 {
		err := MySQLProxyValidationError{
			field:  "StatPrefix",
			reason: "value length must be at least 1 runes",
		}
		if !all {
			return err
		}
		errors = append(errors, err)
	}

	// no validation rules for AccessLog

	if len(errors) > 0 {
		return MySQLProxyMultiError(errors)
	}
	return nil
}

// MySQLProxyMultiError is an error wrapping multiple validation errors
// returned by MySQLProxy.ValidateAll() if the designated constraints aren't met.
type MySQLProxyMultiError []error

// Error returns a concatenation of all the error messages it wraps.
func (m MySQLProxyMultiError) Error() string {
	var msgs []string
	for _, err := range m {
		msgs = append(msgs, err.Error())
	}
	return strings.Join(msgs, "; ")
}

// AllErrors returns a list of validation violation errors.
func (m MySQLProxyMultiError) AllErrors() []error { return m }

// MySQLProxyValidationError is the validation error returned by
// MySQLProxy.Validate if the designated constraints aren't met.
type MySQLProxyValidationError struct {
	field  string
	reason string
	cause  error
	key    bool
}

// Field function returns field value.
func (e MySQLProxyValidationError) Field() string { return e.field }

// Reason function returns reason value.
func (e MySQLProxyValidationError) Reason() string { return e.reason }

// Cause function returns cause value.
func (e MySQLProxyValidationError) Cause() error { return e.cause }

// Key function returns key value.
func (e MySQLProxyValidationError) Key() bool { return e.key }

// ErrorName returns error name.
func (e MySQLProxyValidationError) ErrorName() string { return "MySQLProxyValidationError" }

// Error satisfies the builtin error interface
func (e MySQLProxyValidationError) Error() string {
	cause := ""
	if e.cause != nil {
		cause = fmt.Sprintf(" | caused by: %v", e.cause)
	}

	key := ""
	if e.key {
		key = "key for "
	}

	return fmt.Sprintf(
		"invalid %sMySQLProxy.%s: %s%s",
		key,
		e.field,
		e.reason,
		cause)
}

var _ error = MySQLProxyValidationError{}

var _ interface {
	Field() string
	Reason() string
	Key() bool
	Cause() error
	ErrorName() string
} = MySQLProxyValidationError{}
