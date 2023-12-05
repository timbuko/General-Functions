function processedImage = adjustImageResolution(image, resolution)
    % ADJUSTIMAGERESOLUTION Adjusts the resolution of an image by zero padding or cropping.
    %   processedImage = ADJUSTIMAGERESOLUTION(image, resolution) takes an image matrix 'image' 
    %   and adjusts its resolution to match the desired resolution specified by 'resolution'. 
    %   If the image is larger than the desired resolution, it is cropped by removing the excess edges.
    %   If the image is smaller, it is zero-padded to match the desired resolution, keeping the image centered.
    %
    %   Input:
    %       image - The original image matrix.
    %       resolution - A 2-element vector specifying the desired number of rows and columns.
    %
    %   Output:
    %       processedImage - The processed image with the adjusted resolution.
    
    % Get the current size of the image
    [rows, cols] = size(image);
    if length(resolution)==1;resolution=repmat(resolution,1,2);end
    % Check if image needs to be cropped or zero padded
    if rows > resolution(1) || cols > resolution(2)
        % Crop the image by removing excess edges
        rowStart = floor((rows - resolution(1)) / 2) + 1;
        colStart = floor((cols - resolution(2)) / 2) + 1;
        processedImage = image(rowStart:rowStart+resolution(1)-1, colStart:colStart+resolution(2)-1);
    else
        % Zero pad the image to match the desired resolution
        padRows = resolution(1) - rows;
        padCols = resolution(2) - cols;
        topPad = floor(padRows / 2);
        bottomPad = padRows - topPad;
        leftPad = floor(padCols / 2);
        rightPad = padCols - leftPad;
        processedImage = padarray(image, [topPad, leftPad], 0, 'pre');
        processedImage = padarray(processedImage, [bottomPad, rightPad], 0, 'post');
    end
end
