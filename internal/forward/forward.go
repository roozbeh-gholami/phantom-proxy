package forward

import (
	"context"
	"fmt"
	"phantom-proxy/internal/client"
	"phantom-proxy/internal/flog"
	"golang.org/x/sync/errgroup"
)

type Forward struct {
	client     *client.Client
	listenAddr string
	targetAddr string
	wg         *errgroup.Group
}

func New(client *client.Client, listenAddr, targetAddr string) (*Forward, error) {
	wg := &errgroup.Group{}
	return &Forward{
		client:     client,
		listenAddr: listenAddr,
		targetAddr: targetAddr,
		wg:         wg,
	}, nil
}

func (f *Forward) Start(ctx context.Context, protocol string) error {
	flog.Debugf("starting %s forwarder: %s -> %s", protocol, f.listenAddr, f.targetAddr)
	switch protocol {
	case "tcp":
		return f.startTCP(ctx)
	case "udp":
		return f.startUDP(ctx)
	default:
		flog.Errorf("unsupported protocol: %s", protocol)
		return fmt.Errorf("unsupported protocol: %s", protocol)
	}
}

func (f *Forward) startTCP(ctx context.Context) error {
	f.wg.Go(func() error {
		if err := f.listenTCP(ctx); err != nil {
			flog.Debugf("TCP forwarder stopped with: %v", err)
		}
		return nil
	})
	return nil
}

func (f *Forward) startUDP(ctx context.Context) error {
	f.wg.Go(func() error {
		f.listenUDP(ctx)
		return nil
	})
	return nil
}
