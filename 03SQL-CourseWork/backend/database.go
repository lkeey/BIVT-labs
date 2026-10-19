package main

import (
	"context"
	"database/sql"
	"fmt"
	"reflect"
	"regexp"
	"strings"
)

// SQL Server remains the canonical coursework database. PostgreSQL exposes
// functions with the same procedure contracts for the hosted demonstration.
type appDB struct {
	*sql.DB
	postgres bool
}

var procedureName = regexp.MustCompile(`^(auth|social|knowledge|assistant|ops)\.usp_[A-Za-z0-9_]+$`)

func (d *appDB) isPostgres() bool { return d.postgres }

func (d *appDB) call(query string, args []any) (string, []any) {
	if !d.postgres || !procedureName.MatchString(query) {
		return query, args
	}
	placeholders := make([]string, len(args))
	values := make([]any, len(args))
	for i, arg := range args {
		placeholders[i] = fmt.Sprintf("$%d", i+1)
		if named, ok := arg.(sql.NamedArg); ok {
			arg = named.Value
		}
		value := reflect.ValueOf(arg)
		if value.IsValid() && value.Kind() == reflect.Pointer {
			if value.IsNil() {
				arg = nil
			} else {
				arg = value.Elem().Interface()
			}
		}
		if value := reflect.ValueOf(arg); value.IsValid() && value.Kind() == reflect.String {
			arg = value.String()
		}
		values[i] = arg
	}
	return "SELECT * FROM " + strings.ToLower(query) + "(" + strings.Join(placeholders, ", ") + ")", values
}

func (d *appDB) QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error) {
	query, args = d.call(query, args)
	return d.DB.QueryContext(ctx, query, args...)
}

func (d *appDB) QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row {
	query, args = d.call(query, args)
	return d.DB.QueryRowContext(ctx, query, args...)
}

func (d *appDB) ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error) {
	query, args = d.call(query, args)
	return d.DB.ExecContext(ctx, query, args...)
}
