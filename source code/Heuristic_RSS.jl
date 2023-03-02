#Author: Wissem Ben Marzouk


using Random

function parse_file(filename::String)
    
    # Open the file and read all lines
    if isfile(filename)
     file = open(filename)
     lines = readlines(file)
     
     # Initialize variables to store information
     n=0
     k = 0
     x = []
     y = []
     nbp = []
     capa = []
     ideal = []
     warehouse = (0, 0)
    
     # Parse each line
     for line in lines
        
        # Check if the line starts with "K"
        if startswith(line, "K")
            # Parse the number after "K" as the capacity of the trailer
            k = parse(Int64, split(line)[2])
        elseif startswith(line, "stations")
            # do nothing and break "if" so that this line doesn't get included in "else" condition
        elseif startswith(line, "name")
             # do nothing and break "if" so that this line doesn't get included in "else" condition
        elseif startswith(line, "#")
             # do nothing and break "if" so that this line doesn't get included in "else" condition
        elseif startswith(line, "warehouse")
            # Parse the line as the warehouse coordinates
            coords = split(line)[2:3]
            warehouse = (parse(Int64, coords[1]), parse(Int64, coords[2]))
        else
            
            tab = split(line, " ")
            push!(x, parse(Int64, tab[2]))
            push!(y, parse(Int64, tab[3]))
            push!(nbp, parse(Int64, tab[4]))
            push!(capa, parse(Int64, tab[5]))
            push!(ideal, parse(Int64, tab[6]))
            
        end
     end
     n=size(x, 1)

     # Close the file
     close(file)

     # Return the parsed information
    
    end
     return n, k, warehouse, x, y, nbp, capa, ideal
end

function random_swap(vec::Vector{Int64})
    n = length(vec)
    i, j = rand(1:n), rand(1:n)
    vec[i], vec[j] = vec[j], vec[i]
    return vec
end

function tour_distance(vec::Vector{Int64},d::Array{Int64,2},d_war::Vector{Int64})

    # distances from warehouse to first and last stations
    distance = d_war[vec[1]] + d_war[vec[end]] 

    for i in 1:length(vec)-1

        distance += d[vec[i], vec[i+1]]

    end
    return distance
end
    
function distances(x::Vector{Any}, y::Vector{Any},w::Tuple{Int64, Int64})
    n=size(x, 1)

    d = zeros(Int64, n, n)
    d_war= zeros(Int64, n)
    for i in 1:n
        d_war[i]=round(sqrt((w[1] - x[i])^2 + (w[2] - y[i])^2))
        for j in 1:n
            d[i, j] = round(sqrt((x[i] - x[j])^2 + (y[i] - y[j])^2))
        end
    end
    
    return d, d_war
end

# Calculate the global imbalance given the current state of the stations
function calc_global_imbalance(nbp_work::Vector{Any},ideal::Vector{Any})

    #Initialize the total imbalance 
    imbalance = 0

    for i in 1:length(nbp_work)

        imbalance += abs(nbp_work[i] - ideal[i])

    end

    return imbalance
end

function perform_tour(tour::Vector{Int64},k::Int64, nbp_work::Vector{Any},ideal::Vector{Any})

    # Copy the nbp variable to another variable 
    # so when we ran the code more than once, we don't change the original nbp variable taken from the instance.
    nbp_cur=copy(nbp_work)

    #Initialize variables
    load = zeros(Int, length(nbp_work)+1)
    drop = zeros(Int, length(nbp_work)+1)

    # Randomise the load on the trailer at the warehouse
    load[1] = rand(0:k)

    
    # Iterate through each station on the tour
    for j in 2:length(nbp_work)+1

        # Calculate the imbalance at the current station
        imbalance = nbp_cur[tour[j-1]] - ideal[tour[j-1]]

        # If the station is too empty, unload bikes from the trailer then update load and nbp
        if imbalance < 0

            drop[j] = min(-imbalance, load[j-1])
           
            load[j] = load[j-1] - drop[j]
            
            nbp_cur[tour[j-1]] += drop[j]
           
        # If the station is too full, load bikes on the trailer then update load and nbp
        elseif imbalance > 0

            drop[j] = min(imbalance, k - load[j-1])
            
            load[j] = load[j-1] + drop[j]
           
            nbp_cur[tour[j-1]] -= drop[j]
            drop[j]=-drop[j]
           
        # If the station is balanced, do nothing
        else

            drop[j] = 0
            
            load[j] = load[j-1]
            
        end

        # We will not set conditions utilizing capa[i] because ideal[i] <= capa[i]
        
    end
    
    return nbp_cur,drop,load
end

# Heuristic kailxyv2 function
function kailxyv2(n::Int64,k::Int64, nbp_work::Vector{Any},
ideal::Vector{Any},x::Vector{Any}, y::Vector{Any},w::Tuple{Int64, Int64})

   # calculate distances
   d ,d_war= distances(x,y,w)
   # Set the weighting coefficient
   wight = n * maximum(d)

   # Initialize the current state
   curr_state = copy(nbp_work)
   curr_tour = shuffle(1:n)
   curr_distance=tour_distance(curr_tour,d,d_war)
   curr_cost = wight * calc_global_imbalance(curr_state, ideal) + curr_distance

   # Initialize the load and drop vectors 
   load = zeros(Int, length(nbp_work)+1)
   drop = zeros(Int, length(nbp_work)+1)

   # Set the iteration number for the kailxyv2 loop 
   num_iter = 1000000

   # Initialize the best state ,cost, load and drop
   best_state = copy(curr_state)
   best_cost = curr_cost
   best_drop=copy(drop)
   best_load=copy(load)
   best_tour=curr_tour
   # Start chronometer
   start = time()
   # Perform for a number of iterations
   for i in 1:num_iter

       # Only for the first ietration fill up next_tour and next_distance variables and get them ready for the search (I was lazy to initialize them)  
       if i<2
        next_tour=random_swap(curr_tour)
        next_distance=tour_distance(next_tour,d,d_war)
        # Perform a random tour and update the current state
       else
        curr_tour = shuffle(1:n)
        next_tour=random_swap(curr_tour)
        next_distance=tour_distance(next_tour,d,d_war)
       end
       next_sate,next_drop,next_load=perform_tour(next_tour,k,curr_state,ideal)
       
       #get the next cost 
       next_cost = wight * calc_global_imbalance(next_sate, ideal) + next_distance
       
           # If the new state is the best so far, update the best state and cost
            if  next_cost < best_cost
               best_state = copy(next_sate)
               best_cost = next_cost
               best_drop=copy(next_drop)
               best_load=copy(next_load)
               best_imba=calc_global_imbalance(best_state, ideal)
               d_best=best_cost-wight*best_imba
               println(" ")
               println("Hey guess what! we found a local minima ( hope to escape it though ) at the iteration number ",i," with current imbalance of ",best_imba
               ," and current load 0 = ",best_load[1]," and total distance of ",d_best)
               best_tour=next_tour 
           end
        
    end
       
       imb_final=calc_global_imbalance(best_state, ideal)
       d_final=best_cost-wight*imb_final
       
       finish = time()
       println(" ")
       println("We took ",finish-start," seconds to finish.")
       println(" ")
       println("We start our tour with load 0 = ",best_load[1],".")
       println(" ")
       
       for i in 1:n
        
        println("At step ",i," we go to station ",best_tour[i]," we drop ",best_drop[i+1], ". After the drop operation the trailer has ",best_load[i+1]," bikes.")
        println(" ")
       end
       println("The heuristic optimization resulted in an overall imbalance of ",imb_final,", and total distance of ",d_final,".")

       
    # Open the file and write the header
    file = open("Mini_6_RSS.sol", "w")
    write(file, "name Mini_6\n")
    write(file, "imbalance $imb_final\n")
    write(file, "distance $d_final\n")
    best_loadv=best_load[1]
    write(file, "init_load $best_loadv\n")

    # Write the station header
    write(file, "stations\n")

    j=2
	for i in best_tour
		best_dropv=best_drop[j]
        write(file,"$i $best_dropv\n")
        j+=1        	
	end
	
    # Write the end marker
    write(file, "End\n")

    # Close the file
    close(file)
     
end