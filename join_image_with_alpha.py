import torch

class JoinImageWithAlpha:
    @classmethod
    def INPUT_TYPES(s):
        return {
            "required": {
                "image": ("IMAGE",),
                "alpha": ("MASK",),
            }
        }
    
    RETURN_TYPES = ("IMAGE",)
    FUNCTION = "join"
    CATEGORY = "image/postprocessing"

    def join(self, image, alpha):
        if alpha.ndim == 2:
            alpha = alpha.unsqueeze(0)
        if alpha.shape[0] != image.shape[0]:
            alpha = alpha.repeat(image.shape[0], 1, 1)
        
        alpha_expanded = alpha.unsqueeze(-1)
        rgba = torch.cat([image, alpha_expanded], dim=-1)
        return (rgba,)

NODE_CLASS_MAPPINGS = {
    "JoinImageWithAlpha": JoinImageWithAlpha
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "JoinImageWithAlpha": "Join Image with Alpha"
}
