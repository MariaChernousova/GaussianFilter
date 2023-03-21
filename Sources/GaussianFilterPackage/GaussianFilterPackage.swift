import UIKit

public class GaussianFilterPackage {
    
    public init() {
    }
    
    private var colorRectValues = [[(color: UIColor, rect: CGRect)]]()
    private var queue = DispatchQueue(label: "com.GaussianFilterPackage.serial.queue", attributes: .concurrent)
    
    public func createGaussianFilter(image: UIImage, completion: @escaping (UIImage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Load the input image
            let inputImage = image
            
            // Get the width and height of the input image
            let width = Int(inputImage.size.width)
            let height = Int(inputImage.size.height)
            
            self.colorRectValues = .init(repeating: .init(repeating: (.clear, .zero), count: height), count: width)
            
            // Define the filter parameters
            let sigma = 2.0
            let radius = Int(sigma * 3.0)
            
            // Create a Gaussian kernel
            var kernel = [Double]()
            for i in -radius...radius {
                for j in -radius...radius {
                    let distance = sqrt(Double(i * i + j * j))
                    let weight = exp(-(distance * distance) / (2.0 * sigma * sigma))
                    kernel.append(weight)
                }
            }
            
            // Normalize the kernel
            let kernelSum = kernel.reduce(0, +)
            kernel = kernel.map { $0 / kernelSum }
            
            let group = DispatchGroup()
            // Iterate over each pixel in the input image
            for x in 0..<width {
                for y in 0..<height {
                    DispatchQueue.global(qos: .userInteractive).async(group: group) {
                        // Create variables to hold the color and alpha values of the output pixel
                        var red = 0.0
                        var green = 0.0
                        var blue = 0.0
                        var alpha = 0.0
                        
                        // Iterate over each pixel in the kernel
                        for i in -radius...radius {
                            for j in -radius...radius {
                                // Calculate the coordinates of the current pixel in the input image
                                let xCoord = x + i
                                let yCoord = y + j
                                
                                // Check if the current pixel is within the input image bounds
                                guard xCoord >= 0 && xCoord < width && yCoord >= 0 && yCoord < height else {
                                    continue
                                }
                                
                                // Get the color values of the current pixel
                                guard let pixelColor = inputImage.getPixelColor(x: xCoord, y: yCoord) else { fatalError("")}
                                let pixelRed = Double(pixelColor.red)
                                let pixelGreen = Double(pixelColor.green)
                                let pixelBlue = Double(pixelColor.blue)
                                let pixelAlpha = Double(pixelColor.alpha)
                                
                                // Get the weight of the current kernel pixel
                                let kernelIndex = (i + radius) * (2 * radius + 1) + (j + radius)
                                let kernelWeight = kernel[kernelIndex]
                                
                                // Add the weighted color and alpha values to the output pixel variables
                                red += pixelRed * kernelWeight
                                green += pixelGreen * kernelWeight
                                blue += pixelBlue * kernelWeight
                                alpha += pixelAlpha * kernelWeight
                            }
                        }
                        
                        // Create a new pixel color with the calculated color and alpha values
                        let outputColor = UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
                        let rect = CGRect(x: x, y: y, width: 1, height: 1)
                        
                        self.queue.async(group: group, flags: .barrier) {
                            self.colorRectValues[x][y] = (outputColor, rect)
                        }
                        print("""
----------------------------------
GaussianFilter
x = \(x)
y = \(y)
width = \(width)
height = \(height)
----------------------------------
""")
                    }
                }
            }
            group.notify(queue: .main) {
                // Create a new output image context
                UIGraphicsBeginImageContextWithOptions(inputImage.size, false, inputImage.scale)
                
                for arr in self.colorRectValues {
                    for value in arr {
                        // Set the pixel color in the output image context
                        value.color.setFill()
                        UIRectFill(value.rect)
                    }
                }
                
                
                // Get the output image from the context
                guard let outputImage = UIGraphicsGetImageFromCurrentImageContext() else {
                    fatalError("Output image cannot be accessed.")
                }
                
                // End the image context
                UIGraphicsEndImageContext()
                
                completion(outputImage)
            }
        }
    }
}

extension UIImage {
    func getPixelColor(x: Int, y: Int) -> (red: Double, green: Double, blue: Double, alpha: Double)? {
        guard let cgImage = self.cgImage else {
            return nil
        }
        
        let pixelData = cgImage.dataProvider!.data!
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow
        let pixelOffset = (y * bytesPerRow) + (x * bytesPerPixel)
        let r = CGFloat(data[pixelOffset]) / 255.0
        let g = CGFloat(data[pixelOffset + 1]) / 255.0
        let b = CGFloat(data[pixelOffset + 2]) / 255.0
        let a = (r + g + b)/3
        
        let red = Double(r)
        let green = Double(g)
        let blue = Double(b)
        let alpha = Double(a)
        
        return (red, green, blue, alpha)
    }
}
