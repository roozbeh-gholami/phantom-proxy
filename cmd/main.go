package main

import (
	"os"
	"phantom-proxy/cmd/dump"
	"phantom-proxy/cmd/iface"
	"phantom-proxy/cmd/ping"
	"phantom-proxy/cmd/run"
	"phantom-proxy/cmd/secret"
	"phantom-proxy/cmd/version"
	"phantom-proxy/internal/flog"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "phantom-proxy",
	Short: "KCP transport over raw TCP packet.",
	Long:  `phantom-proxy is a bidirectional packet-level proxy using KCP and raw socket transport with encryption.`,
}

func main() {
	rootCmd.AddCommand(run.Cmd)
	rootCmd.AddCommand(dump.Cmd)
	rootCmd.AddCommand(ping.Cmd)
	rootCmd.AddCommand(secret.Cmd)
	rootCmd.AddCommand(iface.Cmd)
	rootCmd.AddCommand(version.Cmd)

	if err := rootCmd.Execute(); err != nil {
		flog.Errorf("%v", err)
		os.Exit(1)
	}
}
