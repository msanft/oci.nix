package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"

	v1 "github.com/google/go-containerregistry/pkg/v1"
	"github.com/google/go-containerregistry/pkg/v1/empty"
	"github.com/google/go-containerregistry/pkg/v1/layout"
	"github.com/google/go-containerregistry/pkg/v1/mutate"
	"github.com/google/go-containerregistry/pkg/v1/partial"
	"github.com/google/go-containerregistry/pkg/v1/types"
)

// baseImage is the base image for the combined image.
var baseImage, _ = partial.UncompressedToImage(image{})

type image struct{}

// MediaType implements partial.UncompressedImageCore.
func (i image) MediaType() (types.MediaType, error) {
	return types.OCIManifestSchema1, nil
}

// RawConfigFile implements [partial.UncompressedImageCore].
func (i image) RawConfigFile() ([]byte, error) {
	return partial.RawConfigFile(i)
}

// ConfigFile implements [v1.Image].
func (i image) ConfigFile() (*v1.ConfigFile, error) {
	rawConfig, err := os.ReadFile(os.Args[1])
	if err != nil {
		return nil, fmt.Errorf("reading config file %q: %v", os.Args[1], err)
	}

	configFile := &v1.ConfigFile{}
	if err := json.Unmarshal(rawConfig, configFile); err != nil {
		return nil, fmt.Errorf("parsing config file %q: %v", os.Args[1], err)
	}

	// Per go-containerregistry: Some clients check this.
	configFile.RootFS.Type = "layers"

	return configFile, nil
}

func (i image) LayerByDiffID(h v1.Hash) (partial.UncompressedLayer, error) {
	return nil, fmt.Errorf("LayerByDiffID(%s): empty image", h)
}

func main() {
	if len(os.Args) < 4 {
		log.Fatalf("Usage: %s CONFIG IMAGE... OUTPUT", os.Args[0])
	}

	var images []v1.Image
	for _, arg := range os.Args[2 : len(os.Args)-1] {
		layout, err := layout.FromPath(arg)
		if err != nil {
			log.Fatalf("loading image %q: %v", arg, err)
		}
		imagesFromLayout, err := indexToImages(layout)
		if err != nil {
			log.Fatalf("extracting images from layout %q: %v", arg, err)
		}
		images = append(images, imagesFromLayout...)
	}

	if len(images) == 0 {
		log.Fatalf("no images found in input layouts")
	}

	// Convert Docker-defaulting empty image to OCI
	base := baseImage
	manifest, err := base.Manifest()
	if err != nil {
		log.Fatalf("getting base manifest: %v", err)
	}
	manifest.MediaType = types.OCIManifestSchema1
	manifest.Config.MediaType = types.OCIConfigJSON

	for _, img := range images {
		layers, err := img.Layers()
		if err != nil {
			log.Fatalf("getting layers: %v", err)
		}
		for _, l := range layers {
			mediaType, err := l.MediaType()
			if err != nil {
				log.Fatalf("getting media type: %v", err)
			}
			switch mediaType {
			case types.OCILayer, types.OCILayerZStd, types.OCIUncompressedLayer:
				base, err = mutate.AppendLayers(base, l)
				if err != nil {
					log.Fatalf("appending layers: %v", err)
				}
			default:
				log.Printf("Warning: skipping unsupported layer media type %q", mediaType)
			}
		}
	}

	outputPath := os.Args[len(os.Args)-1]
	if err := os.MkdirAll(outputPath, 0755); err != nil {
		log.Fatalf("creating output directory %q: %v", outputPath, err)
	}

	layoutPath, err := layout.Write(outputPath, empty.Index)
	if err != nil {
		log.Fatalf("creating layout at %q: %v", outputPath, err)
	}

	if err := layoutPath.AppendImage(base); err != nil {
		log.Fatalf("writing combined image to %q: %v", outputPath, err)
	}

	log.Printf("Wrote combined image to %q", outputPath)
}

func indexToImages(layout layout.Path) ([]v1.Image, error) {
	index, err := layout.ImageIndex()
	if err != nil {
		return nil, fmt.Errorf("loading index from layout: %v", err)
	}
	return extractImagesFromIndex(index)
}

func extractImagesFromIndex(index v1.ImageIndex) ([]v1.Image, error) {
	manifest, err := index.IndexManifest()
	if err != nil {
		return nil, fmt.Errorf("loading manifest from index: %v", err)
	}

	var images []v1.Image
	for _, desc := range manifest.Manifests {
		switch desc.MediaType {
		case types.OCIImageIndex, types.DockerManifestList:
			nestedIndex, err := index.ImageIndex(desc.Digest)
			if err != nil {
				return nil, fmt.Errorf("loading nested index %q: %v", desc.Digest, err)
			}
			subImages, err := extractImagesFromIndex(nestedIndex)
			if err != nil {
				return nil, fmt.Errorf("loading images from nested index %q: %v", desc.Digest, err)
			}
			images = append(images, subImages...)
		case types.OCIManifestSchema1, types.DockerManifestSchema2, types.DockerManifestSchema1:
			img, err := index.Image(desc.Digest)
			if err != nil {
				return nil, fmt.Errorf("loading image %q: %v", desc.Digest, err)
			}
			images = append(images, img)
		default:
			log.Printf("Warning: skipping unsupported media type %q", desc.MediaType)
		}
	}
	return images, nil
}
