package kcp

import (
	"fmt"
	"net"
	"phantom-proxy/internal/conf"
	"phantom-proxy/internal/flog"
	"phantom-proxy/internal/socket"
	"phantom-proxy/internal/tnet"

	"github.com/xtaci/kcp-go/v5"
	"github.com/xtaci/smux"
)

func Dial(addr *net.UDPAddr, cfg *conf.KCP, pConn *socket.PacketConn) (tnet.Conn, error) {
	conn, err := kcp.NewConn(addr.String(), cfg.Block, cfg.Dshard, cfg.Pshard, pConn)
	if err != nil {
		return nil, fmt.Errorf("connection attempt failed: %v", err)
	}
	aplConf(conn, cfg)
	flog.Debugf("KCP connection established, creating smux session")

	sess, err := smux.Client(conn, smuxConf(cfg))
	if err != nil {
		return nil, fmt.Errorf("failed to create smux session: %w", err)
	}

	flog.Debugf("smux session established successfully")
	return &Conn{pConn, conn, sess}, nil
}
