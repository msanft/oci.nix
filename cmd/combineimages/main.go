package main

import (
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

func main() {
	if len(os.Args) < 3 {
		log.Fatalf("Usage: %s IMAGE... OUTPUT", os.Args[0])
	}

	var images []v1.Image
	for _, arg := range os.Args[1 : len(os.Args)-1] {
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
	base := scratchImage
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
			case types.OCILayer, types.OCILayerZStd, types.OCIUncompressedLayer,
				types.DockerLayer, types.DockerUncompressedLayer:
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

// scratchImage is a singleton empty image, think: FROM scratch.
var scratchImage, _ = partial.UncompressedToImage(emptyImage{})

type emptyImage struct{}

// MediaType implements partial.UncompressedImageCore.
func (i emptyImage) MediaType() (types.MediaType, error) {
	return types.OCIManifestSchema1, nil
}

// RawConfigFile implements partial.UncompressedImageCore.
func (i emptyImage) RawConfigFile() ([]byte, error) {
	return partial.RawConfigFile(i)
}

// ConfigFile implements v1.Image.
func (i emptyImage) ConfigFile() (*v1.ConfigFile, error) {
	return &v1.ConfigFile{
		RootFS: v1.RootFS{
			// Some clients check this.
			Type: "layers",
		},
	}, nil
}

func (i emptyImage) LayerByDiffID(h v1.Hash) (partial.UncompressedLayer, error) {
	return nil, fmt.Errorf("LayerByDiffID(%s): empty image", h)
}
