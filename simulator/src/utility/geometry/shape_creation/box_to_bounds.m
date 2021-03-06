function B = box_to_bounds(l,w,h,c)
% B = box_to_bounds(l,w,h,c)
%
% Given a box defined by length, width, height, and center, make a vector
% containing the box's bounds in the format [xmin xmax ymin ymax zmin zmax]
    xmin = c(1) - l/2 ;
    xmax = c(1) + l/2 ;
    ymin = c(2) - w/2 ;
    ymax = c(2) + w/2 ;
    zmin = c(3) - h/2 ;
    zmax = c(3) + h/2 ;
    
   B = [xmin xmax ymin ymax zmin zmax] ;
end